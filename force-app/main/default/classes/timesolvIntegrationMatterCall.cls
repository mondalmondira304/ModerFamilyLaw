/**
 * @description Queueable job to bulk‐create Matters in TimeSolv for a list of Accounts,
 *              then enqueue Contact creation jobs. 
 * @author Sanders
 * @date 2025-04-18
 */
public class timesolvIntegrationMatterCall implements Queueable, Database.AllowsCallouts {
    @TestVisible
public static Boolean skipChainedContactCall = false;
    private List<Id> accountIds;
    private static final String BASE_URL         = initBaseUrl();
    private static final String PROJECT_ENDPOINT = BASE_URL + '/project';

    public timesolvIntegrationMatterCall(List<Id> accountIds) {
        this.accountIds = accountIds != null ? accountIds : new List<Id>();
    }
  @TestVisible

    public void execute(QueueableContext qc) {
        if (accountIds.isEmpty()) return;

        // 1) Load Matter configuration
        @TestVisible
        Timesolv_Matter_Config__mdt config = [
            SELECT Rate_By__c, Sub_Task_Code_Option__c, Task_Code_Option__c,
                   Client_Sub_Category__c, Global_Rate__c
              FROM Timesolv_Matter_Config__mdt
             LIMIT 1
        ];
        if (config == null) {
            logError(null, 'Failed to retrieve matter configuration');
            return;
        }

        // 2) Fetch Accounts including ResponsibleAttorney lookup fields
        List<Account> accounts = [
            SELECT Id,
                   TimeSolv_Client_Id__c,
                   Responsible_Attorney__c,
                   Responsible_Attorney__r.FirstName,
                   Responsible_Attorney__r.LastName,
                   Type_of_Case_A__c
              FROM Account
             WHERE Id IN :accountIds
        ];
        if (accounts.isEmpty()) {
            logError(null, 'No accounts found for processing');
            return;
        }

        // 3) Retrieve bearer token
        String token = timesolvIntegrationTokenUtil.getBearerToken();
        if (String.isBlank(token)) {
            logError(null, 'Unable to retrieve bearer token');
            return;
        }

        // 4) Build attorney → office map
        Set<Id> attorneyIds = new Set<Id>();
        for (Account a : accounts) {
            if (a.Responsible_Attorney__c != null) {
                attorneyIds.add(a.Responsible_Attorney__c);
            }
        }
        Map<Id,String> attorneyOffices = new Map<Id,String>();
        if (!attorneyIds.isEmpty()) {
            for (User u : [
                SELECT Id, MFL_Office__c
                  FROM User
                 WHERE Id IN :attorneyIds
            ]) {
                attorneyOffices.put(u.Id, u.MFL_Office__c);
            }
        }

        // 5) Load office metadata
        @TestVisible
        Map<String,Timesolv_Office_Location__mdt> officeMeta = new Map<String,Timesolv_Office_Location__mdt>();
        Set<String> labels = new Set<String>(attorneyOffices.values());
        if (!labels.isEmpty()) {
            for (Timesolv_Office_Location__mdt o : [
                SELECT Label, TS_Value__c, TS_ValueId__c
                  FROM Timesolv_Office_Location__mdt
                 WHERE Label IN :labels
            ]) {
                officeMeta.put(o.Label, o);
            }
        }

        // 6) Build MatterRequest payloads
        List<MatterRequest> reqs = new List<MatterRequest>();
        for (Account a : accounts) {
            if (String.isBlank(a.TimeSolv_Client_Id__c)) continue;

            MatterRequest mr = new MatterRequest();
            mr.ClientId             = a.TimeSolv_Client_Id__c;
            mr.ProjectName          = !String.isBlank(a.Type_of_Case_A__c)
                                      ? a.Type_of_Case_A__c
                                      : 'Default';
            mr.RateBy               = config.Rate_By__c;
            mr.GlobalRate           = config.Global_Rate__c;
            mr.SubTaskCodeOption    = config.Sub_Task_Code_Option__c;
            mr.TaskCodeOption       = config.Task_Code_Option__c;
            mr.ClientSubCategory    = config.Client_Sub_Category__c;
            // set ResponsibleTimeKeeper from lookup fields
            mr.ResponsibleTimeKeeper = a.Responsible_Attorney__r != null
                                        ? a.Responsible_Attorney__r.LastName + ', ' + a.Responsible_Attorney__r.FirstName
                                        : null;

            String lbl = attorneyOffices.get(a.Responsible_Attorney__c);
            Timesolv_Office_Location__mdt meta = officeMeta.get(lbl);
            if (meta != null) {
                mr.ClientCategory   = meta.TS_Value__c;
                mr.ClientCategoryId = Integer.valueOf(meta.TS_ValueId__c);
            }
            reqs.add(mr);
        }
        if (reqs.isEmpty()) return;

        // 7) Single bulk callout
        HttpRequest r = new HttpRequest();
        r.setEndpoint(PROJECT_ENDPOINT);
        r.setMethod('POST');
        r.setHeader('Content-Type','application/json');
        r.setHeader('Authorization','Bearer ' + token);
        r.setBody(JSON.serialize(reqs));

        HttpResponse resp;
        try {
            resp = new Http().send(r);
        } catch (Exception e) {
            logError(null, 'Callout exception: ' + e.getMessage());
            return;
        }
        Integer code = resp.getStatusCode();
        if (code != 200 && code != 201) {
            logError(null, 'API error ('+code+'): '+resp.getBody());
            return;
        }

        // 8) Parse response
        MatterApiResponse mar = (MatterApiResponse)JSON.deserialize(resp.getBody(), MatterApiResponse.class);
        Map<Id,String> created = new Map<Id,String>();
        for (Integer i = 0; i < accounts.size() && i < mar.Details.size(); i++) {
            Integer projId = mar.Details[i].Id;
            if (projId != null) {
                created.put(accounts[i].Id, String.valueOf(projId));
            }
        }

        // 9) Update status on Accounts
        for (Account a : accounts) {
            if (created.containsKey(a.Id)) {
                TimeSolvIntegrationStatusTask.updateIntegrationStatusTask(
                    a, 'Matter Creation', 'Success',
                    'Matter ID: ' + created.get(a.Id),
                    null
                );
            } else {
                TimeSolvIntegrationStatusTask.updateIntegrationStatusTask(
                    a, 'Matter Creation', 'Error',
                    'No Matter ID returned',
                    null
                );
            }
        }

        // 10) DML: update Account.MatterId
        if (!created.isEmpty()) {
            List<Account> upd = new List<Account>();
            for (Id aid : created.keySet()) {
                upd.add(new Account(
                    Id                   = aid,
                    TimeSolv_Matter_Id__c = created.get(aid)
                ));
            }
            update upd;

            // 11) Enqueue Contact creation for each new Matter
            if (!skipChainedContactCall
        && Limits.getQueueableJobs() < Limits.getLimitQueueableJobs()) {
                Map<Id,String> clientMap = new Map<Id,String>();
                for (Account a : [
                    SELECT Id, TimeSolv_Client_Id__c
                      FROM Account
                     WHERE Id IN :created.keySet()
                ]) {
                    clientMap.put(a.Id, a.TimeSolv_Client_Id__c);
                }
                for (Id acctId : created.keySet()) {
                    System.enqueueJob(new timesolvIntegrationContactCall(
                        acctId,
                        clientMap.get(acctId),
                        token,
                        created.get(acctId)
                    ));
                }
            }
        }
    }

    //───────────────────────────────────────────────────────────────────────────
    // Helpers & DTOs
    //───────────────────────────────────────────────────────────────────────────

    private static String initBaseUrl() {
        TimeSolv_Integration_Configuration__mdt  ep = [
            SELECT Endpoint_URL__c
              FROM TimeSolv_Integration_Configuration__mdt 
             WHERE Label='Production'
             LIMIT 1
        ];
        return ep != null ? ep.Endpoint_URL__c : '';
    }

    private void logError(Id acctId, String msg) {
        TimeSolvIntegrationLogUtil.logError(
            acctId,
            TimeSolvIntegrationLogUtil.INTEGRATION_TYPE_MATTER,
            msg,
            null
        );
    }

    public class MatterRequest {
        public String  ClientId;
        public String  ProjectName;
        public String  RateBy;
        public String  GlobalRate;
        public String  SubTaskCodeOption;
        public String  TaskCodeOption;
        public String  ClientSubCategory;
        public String  ClientCategory;
        public Integer ClientCategoryId;
        public String  ResponsibleTimeKeeper;
    }

    public class MatterDetail { public Integer Id; }
    public class MatterApiResponse { public List<MatterDetail> Details; }
}