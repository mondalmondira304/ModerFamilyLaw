public class timesolvInvoiceRetainerCallQueueable implements Queueable, Database.AllowsCallouts {
    private String projectId;
    private String bearerToken;
    private Id    accountId;

    private static final String BASE_URL         = initBaseUrl();
    private static final String RETAINER_ENDPOINT = BASE_URL + '/invoiceRetainer';

    public timesolvInvoiceRetainerCallQueueable(String projectId, String bearerToken) {
        this(projectId, bearerToken, null);
    }
    public timesolvInvoiceRetainerCallQueueable(String projectId, String bearerToken, Id accountId) {
        this.projectId   = projectId;
        this.bearerToken = bearerToken;
        this.accountId   = accountId;
    }

    public void execute(QueueableContext qc) {
        System.debug('==> [InvoiceRetainer] START projectId=' + projectId + ' accountId=' + accountId);

        // 1) Fetch Account and retainer amount
        List<Account> accList = [
            SELECT Id,
                   Quoted_Retainer__c,Additional_Retainer_Amount__c,
                   PersonEmail,
                   Responsible_Attorney__r.MFL_Office__c
              FROM Account
             WHERE TimeSolv_Matter_Id__c = :projectId
             LIMIT 1
        ];
        System.debug('==> [InvoiceRetainer] SOQL returned ' + accList.size() + ' account(s)');
        if (accList.isEmpty()) {
            logError(null, 'No Account found for Matter ID: ' + projectId);
            return;
        }
        Account acc = accList[0];
        System.debug('==> [InvoiceRetainer] Fetched Account: ' + acc);

        if (accountId == null) {
            accountId = acc.Id;
            System.debug('==> [InvoiceRetainer] accountId set to ' + accountId);
        }

        // 2) Sum Quoted_Retainer__c + Additional_Retainer_Amount__c (default 0 if null)
        Decimal retainerAmt = 
            (acc.Quoted_Retainer__c != null ? acc.Quoted_Retainer__c : 0)
          + (acc.Additional_Retainer_Amount__c != null ? acc.Additional_Retainer_Amount__c : 0);
        System.debug('==> [InvoiceRetainer] retainerAmt=' + retainerAmt);

if (retainerAmt == 0) {
    //  — bypass the API, since Timesolv will reject zero
    System.debug('==> [InvoiceRetainer] Zero retainer – skipping Timesolv call');
    updateStatus(acc.Id, 
        'Success', 
        'Zero (Gold) retainer – no invoice created'
    );
    return;
}

        // 3) Build payload
        Map<String, Object> invoice = new Map<String, Object>();
        invoice.put('Title', 'New');
        invoice.put('ProjectId', projectId);
        invoice.put('Date', Datetime.now().format('yyyy-MM-dd','GMT'));
        invoice.put('RetainerNumber', '');
        invoice.put('RetainerAmount', retainerAmt);
        invoice.put('Message', '');
        invoice.put('SendByEmail', false);
        invoice.put('IncludeFromAddress', false);
        invoice.put('EmailAddress', acc.PersonEmail);
        invoice.put('EmailIncludeClientPortalLink', true);

        List<Map<String,Object>> bodyList = new List<Map<String,Object>>{ invoice };
        String jsonBody = JSON.serialize(bodyList);
        System.debug('==> [InvoiceRetainer] Payload JSON: ' + jsonBody);

        // 4) Perform callout
        HttpRequest req = new HttpRequest();
        req.setEndpoint(RETAINER_ENDPOINT);
        req.setMethod('POST');
        req.setHeader('Content-Type','application/json');
        req.setHeader('Authorization','Bearer ' + bearerToken);
        req.setBody(jsonBody);
        System.debug('==> [InvoiceRetainer] Calling ' + RETAINER_ENDPOINT);

        HttpResponse res;
        try {
            res = new Http().send(req);
        } catch (Exception e) {
            System.debug('==> [InvoiceRetainer] Callout exception: ' + e.getMessage());
            logError(acc.Id, 'Callout exception: ' + e.getMessage(), e);
            updateStatus(acc.Id, 'Error', 'Callout exception');
            return;
        }
        System.debug('==> [InvoiceRetainer] Response status=' + res.getStatusCode());
        System.debug('==> [InvoiceRetainer] Response body=' + res.getBody());

        // 5) Validate status code
        Integer status = res.getStatusCode();
        if (status != 200 && status != 201) {
            logError(acc.Id, 'API error (' + status + '): ' + res.getBody());
            updateStatus(acc.Id, 'Error', 'API error: ' + status);
            return;
        }

        // 6) Parse payment link & Id
String paymentLink;
String responseId;

try {
    Map<String,Object> respMap = (Map<String,Object>) JSON.deserializeUntyped(res.getBody());
    if (respMap.containsKey('Details')) {
        List<Object> details = (List<Object>) respMap.get('Details');
        if (!details.isEmpty()) {
            Map<String,Object> d0 = (Map<String,Object>) details[0];
            // Existing logic for paymentLink...
            if (d0.containsKey('Message')) {
                paymentLink = (String) d0.get('Message');
            }
            // === NEW LOGIC: Save API Id ===
            if (d0.containsKey('Id')) {
                responseId = String.valueOf(d0.get('Id'));
            }
        }
    }
    System.debug('==> [InvoiceRetainer] Extracted paymentLink=' + paymentLink);
    System.debug('==> [InvoiceRetainer] Extracted responseId=' + responseId);
} catch (Exception e) {
    System.debug('==> [InvoiceRetainer] Error parsing response: ' + e.getMessage());
    logError(acc.Id, 'Error parsing payment link: ' + e.getMessage(), e);
}


        // 7) Update Account with link + status
        try {
    // Save payment link if present
    if (paymentLink != null) {
        if (paymentLink.length() <= 255) {
            acc.Invoice_Retainer_URL1__c = paymentLink;
            acc.Invoice_Retainer_URL2__c = null;
        } else {
            acc.Invoice_Retainer_URL1__c = paymentLink.substring(0, 255);
            acc.Invoice_Retainer_URL2__c = paymentLink.substring(255);
        }
    }

    // Save API response Id
    if (responseId != null) {
        acc.Invoice_Retainer_Id__c = responseId;
    }

    update acc;
    System.debug('==> [InvoiceRetainer] Account updated with paymentLink and responseId');
    updateStatus(
        acc.Id,
        'Success',
        'Retainer created; payment link and Invoice Retainer Id updated'
    );
} catch (Exception e) {
    System.debug('==> [InvoiceRetainer] DML exception: ' + e.getMessage());
    logError(acc.Id, 'Error updating Account: ' + e.getMessage(), e);
    updateStatus(acc.Id, 'Error', 'Error updating Account');
}

        System.debug('==> [InvoiceRetainer] FINISH');
    }

    private static String initBaseUrl() {
        TimeSolv_Integration_Configuration__mdt ep = [
            SELECT Endpoint_URL__c
              FROM TimeSolv_Integration_Configuration__mdt
             WHERE Label='Production'
             LIMIT 1
        ];
        String url = ep != null ? ep.Endpoint_URL__c : '';
        System.debug('==> [InvoiceRetainer] BASE_URL=' + url);
        return url;
    }

    private void logError(Id acctId, String msg) {
        TimeSolvIntegrationLogUtil.logError(acctId,
            TimeSolvIntegrationLogUtil.INTEGRATION_TYPE_RETAINER,
            msg,
            null
        );
    }
    private void logError(Id acctId, String msg, Exception e) {
        TimeSolvIntegrationLogUtil.logError(acctId,
            TimeSolvIntegrationLogUtil.INTEGRATION_TYPE_RETAINER,
            msg,
            e
        );
    }
    private void logWarning(Id acctId, String msg) {
        TimeSolvIntegrationLogUtil.logWarning(acctId,
            TimeSolvIntegrationLogUtil.INTEGRATION_TYPE_RETAINER,
            msg
        );
    }
    private void updateStatus(Id acctId, String status, String message) {
        TimeSolvIntegrationStatusTask.updateIntegrationStatusTask(
            new Account(Id = acctId),
            'Invoice Retainer',
            status,
            message,
            null
        );
    }
}