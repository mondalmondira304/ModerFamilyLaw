public class timesolvIntegrationTrustAccountCall implements Queueable, Database.AllowsCallouts {
    private String projectId;
    private String bearerToken;
    private Id    accountId;

    private static final String BASE_URL       = initBaseUrl();
    private static final String TRUST_ENDPOINT = BASE_URL + '/trustAccount';

    public timesolvIntegrationTrustAccountCall(String projectId, String bearerToken) {
        this(projectId, bearerToken, null);
    }
    public timesolvIntegrationTrustAccountCall(String projectId, String bearerToken, Id accountId) {
        this.projectId   = projectId;
        this.bearerToken = bearerToken;
        this.accountId   = accountId;
    }

    public void execute(QueueableContext qc) {
        System.debug('==> [TrustAccount] START projectId=' + projectId + ' accountId=' + accountId);

        // 1) Query the Account by Matter ID, include attorney office and quoted retainer
        Account acc = [
            SELECT Id,
                   Timesolv_trustAccount_Id__c,
                   Quoted_Retainer__c,
                   Responsible_Attorney__r.MFL_Office__c
              FROM Account
             WHERE TimeSolv_Matter_Id__c = :projectId
             LIMIT 1
        ];
        if (acc == null) {
            System.debug('==> [TrustAccount] No Account for Matter=' + projectId);
            logWarning(null, 'No Account found for Matter ID: ' + projectId);
            return;
        }
        System.debug('==> [TrustAccount] Fetched Account: ' + acc);

        if (accountId == null) {
            accountId = acc.Id;
            System.debug('==> [TrustAccount] accountId set to ' + accountId);
        }

        // 2) Use Quoted_Retainer__c for replenishment thresholds
        Decimal replenishAmount = acc.Quoted_Retainer__c != null ? acc.Quoted_Retainer__c : 0;
        System.debug('==> [TrustAccount] replenishAmount=' + replenishAmount);

        // 3) Pull raw office string off the Attorney
String rawOffice = acc.Responsible_Attorney__r?.MFL_Office__c;
System.debug('Office from Attorney record = ' + rawOffice);

// 4) Fetch all office-location MD rows, then match ignoring case
Integer bankId = 0;
if (String.isNotBlank(rawOffice)) {
    List<Timesolv_Office_Location__mdt> allLocs = [
       SELECT Label, Default_Trust_Bank_Account_Id__c
         FROM Timesolv_Office_Location__mdt
    ];
    for (Timesolv_Office_Location__mdt m : allLocs) {
        if (m.Label.equalsIgnoreCase(rawOffice.trim())) {
            bankId = Integer.valueOf(m.Default_Trust_Bank_Account_Id__c);
            System.debug('Matched MDT label `' + m.Label + '` → bankId=' + bankId);
            break;
        }
    }
    if (bankId == 0) {
        logWarning(
            acc.Id,
            'No Default_Trust_Bank_Account_Id found for office: ' +
            rawOffice
        );
    }
} else {
    logWarning(acc.Id, 'Responsible Attorney has no MFL_Office__c');
}
System.debug('==> [TrustAccount] bankId=' + bankId);
        // 5) Build TrustAccountRequest
        TrustAccountRequest reqBody = new TrustAccountRequest();
        reqBody.ProjectId          = Integer.valueOf(projectId);
        reqBody.Name               = 'Trust';
        reqBody.TrustBankAccountId = bankId;
        reqBody.ReplenishBelow     = replenishAmount;
        reqBody.ReplenishTo        = replenishAmount;
        reqBody.hasAutoPayInvoices = false;
        reqBody.isDefault          = true;
        reqBody.isActive           = true;
        System.debug('==> [TrustAccount] Payload: ' + JSON.serialize(reqBody));

        // 6) Perform HTTP callout
        HttpRequest httpReq = new HttpRequest();
        httpReq.setEndpoint(TRUST_ENDPOINT);
        httpReq.setMethod('POST');
        httpReq.setHeader('Content-Type','application/json');
        httpReq.setHeader('Authorization','Bearer ' + bearerToken);
        httpReq.setBody(JSON.serialize(new List<TrustAccountRequest>{ reqBody }));
        System.debug('==> [TrustAccount] Calling ' + TRUST_ENDPOINT);

        HttpResponse res;
        try {
            res = new Http().send(httpReq);
        } catch (Exception e) {
            System.debug('==> [TrustAccount] Callout exception: ' + e.getMessage());
            logError(acc.Id, 'Callout exception: ' + e.getMessage(), e);
            updateStatus(acc.Id, 'Error', 'Callout exception');
            return;
        }
        System.debug('==> [TrustAccount] Response code=' + res.getStatusCode());
        System.debug('==> [TrustAccount] Response body=' + res.getBody());

        // 7) Process response
        Integer code = res.getStatusCode();
        if (code != 200 && code != 201) {
            logError(acc.Id, 'API error (' + code + '): ' + res.getBody());
            updateStatus(acc.Id, 'Error', 'API error: ' + code);
            return;
        }
        TrustAccountApiResponse apiResp = (TrustAccountApiResponse)
            JSON.deserialize(res.getBody(), TrustAccountApiResponse.class);
        System.debug('==> [TrustAccount] Parsed response: ' + apiResp);
        if (apiResp == null || apiResp.Details == null || apiResp.Details.isEmpty()) {
            logWarning(acc.Id, 'No Trust Account ID returned');
            updateStatus(acc.Id, 'Warning', 'No ID returned');
            return;
        }

        // 8) Update Account record
        String trustId = String.valueOf(apiResp.Details[0].Id);
        System.debug('==> [TrustAccount] Received trustId=' + trustId);
        acc.Timesolv_trustAccount_Id__c = trustId;
        update acc;
        System.debug('==> [TrustAccount] Account updated');
        updateStatus(acc.Id, 'Success', 'Trust Account ID: ' + trustId);

        // 9) Enqueue Invoice Retainer job
        if (!Test.isRunningTest()) {
            if (Limits.getQueueableJobs() < Limits.getLimitQueueableJobs()) {
                System.enqueueJob(
                    new timesolvInvoiceRetainerCallQueueable(projectId, bearerToken, acc.Id)
                );
                TimeSolvIntegrationStatusTask.updateIntegrationStatusTask(
                    acc, 'Invoice Retainer', 'Queued', 'Invoice Retainer queued', null
                );
            } else {
                logWarning(acc.Id, 'Could not enqueue Invoice Retainer – queueable limit reached');
                updateStatus(acc.Id, 'Warning', 'Invoice Retainer not queued');
            }
        }

        System.debug('==> [TrustAccount] COMPLETE');
    }

    private static String initBaseUrl() {
        if (Test.isRunningTest()) {
            return 'https://test.timesolv';
        }
        TimeSolv_Integration_Configuration__mdt  ep = [
            SELECT Endpoint_URL__c    
              FROM TimeSolv_Integration_Configuration__mdt 
             WHERE Label='Production'
             LIMIT 1
        ];
        String url = (ep != null ? ep.Endpoint_URL__c : '');
        System.debug('==> [TrustAccount] BASE_URL=' + url);
        return url;
    }

    private void logError(Id acctId, String msg) {
        TimeSolvIntegrationLogUtil.logError(acctId, TimeSolvIntegrationLogUtil.INTEGRATION_TYPE_TRUST, msg, null);
    }
    private void logError(Id acctId, String msg, Exception e) {
        TimeSolvIntegrationLogUtil.logError(acctId, TimeSolvIntegrationLogUtil.INTEGRATION_TYPE_TRUST, msg, e);
    }
    private void logWarning(Id acctId, String msg) {
        TimeSolvIntegrationLogUtil.logWarning(acctId, TimeSolvIntegrationLogUtil.INTEGRATION_TYPE_TRUST, msg);
    }
    private void updateStatus(Id acctId, String status, String message) {
        TimeSolvIntegrationStatusTask.updateIntegrationStatusTask(
            new Account(Id = acctId),
            'Trust Account Creation',
            status,
            message,
            null
        );
    }

    public class TrustAccountRequest {
        public Integer ProjectId          { get; set; }
        public String  Name               { get; set; }
        public Integer TrustBankAccountId { get; set; }
        public Decimal ReplenishBelow     { get; set; }
        public Decimal ReplenishTo        { get; set; }
        public Boolean hasAutoPayInvoices { get; set; }
        public Boolean isDefault          { get; set; }
        public Boolean isActive           { get; set; }
    }
    public class TrustAccountDetail { public Integer Id; }
    public class TrustAccountApiResponse { public List<TrustAccountDetail> Details; }
}