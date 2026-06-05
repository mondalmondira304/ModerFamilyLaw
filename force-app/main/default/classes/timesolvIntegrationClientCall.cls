public class timesolvIntegrationClientCall implements Queueable, Database.AllowsCallouts {
    private List<Id> accIds;
    private static String timesolvBaseUrl;
    
    private Integer totalProcessed         = 0;
    private Integer totalSuccessful        = 0;
    private Integer totalTasksCreated      = 0;
    private Integer totalErrorTasksCreated = 0;
    
    //───────────────────────────────────────────────────────────────────────────
    // Static initializer to set base URL 
    //───────────────────────────────────────────────────────────────────────────
    static {
        timesolvBaseUrl = getBaseUrl();
    }
    
    /** @TestVisible — returns stub in tests or real metadata in prod */
    @TestVisible
    private static String getBaseUrl() {
        if (Test.isRunningTest()) {
            return 'https://api.timesolv.com';
        }
        TimeSolv_Integration_Configuration__mdt  ep = [
            SELECT Endpoint_URL__c
              FROM TimeSolv_Integration_Configuration__mdt 
             WHERE Label = 'Production'
             LIMIT 1
        ];
        return (ep != null ? ep.Endpoint_URL__c : '');
    }
    
    public timesolvIntegrationClientCall(List<Id> accIds) {
        this.accIds = accIds != null ? accIds : new List<Id>();
    }
    
    public void execute(QueueableContext qc) {
        Timesolv_Client_Config__mdt config = getTimesolvClientConfig();
        if (config == null) {
            TimeSolvIntegrationLogUtil.logError(
                null,
                TimeSolvIntegrationLogUtil.INTEGRATION_TYPE_CLIENT,
                'Failed to retrieve TimeSolv client configuration',
                null
            );
            return;
        }
        
        try {
            processAccounts(config);
        } catch (Exception e) {
            TimeSolvIntegrationLogUtil.logError(
                null,
                TimeSolvIntegrationLogUtil.INTEGRATION_TYPE_CLIENT,
                'Unhandled exception: ' + e.getMessage(),
                e
            );
        }
    }
    
    //───────────────────────────────────────────────────────────────────────────
    // Stubbed client-config lookup
    //───────────────────────────────────────────────────────────────────────────
    @TestVisible
    private Timesolv_Client_Config__mdt getTimesolvClientConfig() {
        if (Test.isRunningTest()) {
            return new Timesolv_Client_Config__mdt(
                Client_Status__c        = 'Active',
                Payment_Routing__c      = 'ACH',
                Rate_By__c              = 'Hourly',
                Global_Rate__c          = '200',
                Default_Sub_Category__c = 'General'
            );
        }
        return [
            SELECT Client_Status__c, Payment_Routing__c,
                   Rate_By__c, Global_Rate__c, Default_Sub_Category__c
              FROM Timesolv_Client_Config__mdt
             LIMIT 1
        ];
    }
    
    //───────────────────────────────────────────────────────────────────────────
    // Main processing logic
    //───────────────────────────────────────────────────────────────────────────
    private void processAccounts(Timesolv_Client_Config__mdt config) {
        if (accIds.isEmpty()) return;
        
        List<Account> accounts = [
            SELECT Id, FirstName, LastName, TimeSolv_Client_Id__c,
                   Responsible_Attorney__c, Timesolv_Client_Number__c
              FROM Account
             WHERE Id IN :accIds
        ];
        totalProcessed = accounts.size();
        if (accounts.isEmpty()) return;
        
        Timesolv_Matter__mdt matterStatus = getMatterStatus();
        Map<Id, User> attorneyMap          = getAttorneyMap(accounts);
        Map<String, Timesolv_Office_Location__mdt> officeMap
            = getOfficeLocationMap(attorneyMap.values());
        
        String bearerToken = timesolvIntegrationTokenUtil.getBearerToken();
        if (String.isBlank(bearerToken)) {
            TimeSolvIntegrationLogUtil.logError(
                null,
                TimeSolvIntegrationLogUtil.INTEGRATION_TYPE_CLIENT,
                'Unable to retrieve bearer token',
                null
            );
            return;
        }
        
        List<Account> toUpdate                 = new List<Account>();
        Map<Id, TimeSolv_Integration_Log__c> errorLogMap = new Map<Id, TimeSolv_Integration_Log__c>();
        
        for (Account acc : accounts) {
            try {
                ClientCreationResult res = callCreateClientAPI(
                    acc, bearerToken, matterStatus, officeMap,
                    acc.Responsible_Attorney__c!=null && attorneyMap.containsKey(acc.Responsible_Attorney__c)
                      ? attorneyMap.get(acc.Responsible_Attorney__c).MFL_Office__c
                      : null,
                    config
                );
                if (res.success) {
                    toUpdate.add(acc);
                    totalSuccessful++;
                }
                if (res.log != null && res.log.Type__c == TimeSolvIntegrationLogUtil.LOG_TYPE_ERROR) {
                    errorLogMap.put(acc.Id, res.log);
                }
            } catch (Exception e) {
                TimeSolv_Integration_Log__c log = TimeSolvIntegrationLogUtil.logError(
                    acc.Id,
                    TimeSolvIntegrationLogUtil.INTEGRATION_TYPE_CLIENT,
                    'Error processing account',
                    e
                );
                errorLogMap.put(acc.Id, log);
            }
        }
        
        // Insert error logs & tasks
        if (!errorLogMap.isEmpty()) {
            List<TimeSolv_Integration_Log__c> errs = errorLogMap.values();
            insert errs;
            List<Task> errTasks = new List<Task>();
            for (TimeSolv_Integration_Log__c l : errs) {
                errTasks.add(TimeSolvIntegrationLogUtil.createTaskFromLog(l));
            }
            insert errTasks;
            totalErrorTasksCreated += errTasks.size();
        }
        
        // Update status on each account
        for (Account acc : accounts) {
            String status, message;
            Id logId = null;
            
            if (errorLogMap.containsKey(acc.Id)) {
                status  = 'Error';
                message = errorLogMap.get(acc.Id).Message__c;
                logId   = errorLogMap.get(acc.Id).Id;
            } else if (toUpdate.contains(acc)) {
                status  = 'Success';
                message = 'Client ID: ' + acc.TimeSolv_Client_Id__c +
                          ', Client Number: ' + acc.Timesolv_Client_Number__c;
            } else {
                status  = 'Warning';
                message = 'Processed but no log created';
            }
            
            TimeSolvIntegrationStatusTask.updateIntegrationStatusTask(
                acc, 'Client Creation', status, message, logId
            );
        }
        
        // Final updates & enqueue Matter call
        updateAccountsAndEnqueueMatter(toUpdate);
    }
    
    //───────────────────────────────────────────────────────────────────────────
    // Stubbed Matter-status lookup
    //───────────────────────────────────────────────────────────────────────────
    @TestVisible
    private Timesolv_Matter__mdt getMatterStatus() {
        if (Test.isRunningTest()) {
            return new Timesolv_Matter__mdt(
                Label        = 'Open',
                TS_Value__c  = 'OpenVal',
                TS_ValueId__c= '1'
            );
        }
        return [
            SELECT TS_Value__c, TS_ValueId__c
              FROM Timesolv_Matter__mdt
             WHERE Label = 'Open'
             LIMIT 1
        ];
    }
    
    //───────────────────────────────────────────────────────────────────────────
    // Attorney → User map
    //───────────────────────────────────────────────────────────────────────────
    private Map<Id, User> getAttorneyMap(List<Account> acctList) {
        Set<Id> ids = new Set<Id>();
        for (Account a : acctList) {
            if (a.Responsible_Attorney__c != null) {
                ids.add(a.Responsible_Attorney__c);
            }
        }
        if (ids.isEmpty()) return new Map<Id, User>();
        return new Map<Id, User>([
            SELECT Id, MFL_Office__c
              FROM User
             WHERE Id IN :ids
        ]);
    }
    
    //───────────────────────────────────────────────────────────────────────────
    // Stubbed Office-location lookup
    //───────────────────────────────────────────────────────────────────────────
    @TestVisible
    private Map<String, Timesolv_Office_Location__mdt> getOfficeLocationMap(List<User> attorneys) {
        Set<String> labels = new Set<String>();
        for (User u : attorneys) {
            if (u.MFL_Office__c != null) {
                labels.add(u.MFL_Office__c);
            }
        }
        if (Test.isRunningTest()) {
            Map<String, Timesolv_Office_Location__mdt> stub = new Map<String, Timesolv_Office_Location__mdt>();
            for (String lbl : labels) {
                stub.put(lbl, new Timesolv_Office_Location__mdt(
                    Label        = lbl,
                    TS_Value__c  = 'CatA',
                    TS_ValueId__c= '42'
                ));
            }
            return stub;
        }
        Map<String, Timesolv_Office_Location__mdt> realMap = new Map<String, Timesolv_Office_Location__mdt>();
        for (Timesolv_Office_Location__mdt loc : [
            SELECT Label, TS_Value__c, TS_ValueId__c
              FROM Timesolv_Office_Location__mdt
             WHERE Label IN :labels
        ]) {
            realMap.put(loc.Label, loc);
        }
        return realMap;
    }
    
    //───────────────────────────────────────────────────────────────────────────
    // Updates & enqueues the Matter call
    //───────────────────────────────────────────────────────────────────────────
    private void updateAccountsAndEnqueueMatter(List<Account> toUpdate) {
        if (toUpdate.isEmpty()) return;
        update toUpdate;
        
        // create success Tasks
        List<Task> successTasks = new List<Task>();
        for (Account a : toUpdate) {
            successTasks.add(new Task(
                WhatId       = a.Id,
                Subject      = 'TimeSolv Client Created: ' + a.Timesolv_Client_Number__c,
                Status       = 'Completed',
                Priority     = 'Normal',
                Type         = 'TimeSolv',
                ActivityDate = Date.today(),
                Description  = 'Client: ' + a.FirstName + ' ' + a.LastName +
                               '\nClient Number: ' + a.Timesolv_Client_Number__c
                             
            ));
        }
        if (!successTasks.isEmpty()) {
            insert successTasks;
            totalTasksCreated += successTasks.size();
        }
        
        // enqueue Matter call
        List<Id> ids = new List<Id>();
        for (Account a : toUpdate) ids.add(a.Id);
        if (!ids.isEmpty() && Limits.getQueueableJobs() < Limits.getLimitQueueableJobs()) {
            System.enqueueJob(new timesolvIntegrationMatterCall(ids));
            for (Account a : toUpdate) {
                TimeSolvIntegrationStatusTask.updateIntegrationStatusTask(
                    a, 'Matter Creation', 'Queued',
                    'Matter creation queued', null
                );
            }
        } else if (!ids.isEmpty()) {
            TimeSolv_Integration_Log__c w = TimeSolvIntegrationLogUtil.logWarning(
                null,
                TimeSolvIntegrationLogUtil.INTEGRATION_TYPE_CLIENT,
                'Could not enqueue matter call – queueable limit reached'
            );
            insert w;
            insert TimeSolvIntegrationLogUtil.createTaskFromLog(w);
            totalErrorTasksCreated++;
            for (Account a : toUpdate) {
                TimeSolvIntegrationStatusTask.updateIntegrationStatusTask(
                    a, 'Matter Creation', 'Warning',
                    'Queueable limit reached', w.Id
                );
            }
        }
    }
    
    //───────────────────────────────────────────────────────────────────────────
    // DTOs & API methods (unchanged)
    //───────────────────────────────────────────────────────────────────────────
    public class ClientCreationResult {
        public Boolean success;
        public TimeSolv_Integration_Log__c log;
        public ClientCreationResult(Boolean s, TimeSolv_Integration_Log__c l) {
            success = s; log = l;
        }
    }
    
    public static ClientCreationResult callCreateClientAPI(
        Account acc,
        String bearerToken,
        Timesolv_Matter__mdt matterStatus,
        Map<String, Timesolv_Office_Location__mdt> officeMap,
        String officeLabel,
        Timesolv_Client_Config__mdt cfg
    ) {
        TimeSolv_Integration_Log__c logRec;
        Boolean success = false;
        try {
            ClientRequest req = new ClientRequest();
            req.ClientName           = acc.LastName + ', ' + acc.FirstName;
            req.ClientStatus         = cfg.Client_Status__c;
            req.InvoiceName          = req.ClientName;
            req.OpenDate             = Date.today();
            req.RateBy               = cfg.Rate_By__c;
            req.GlobalRate           = cfg.Global_Rate__c;
            req.PaymentRoutingOption = cfg.Payment_Routing__c;
            if (officeMap.containsKey(officeLabel)) {
                Timesolv_Office_Location__mdt loc = officeMap.get(officeLabel);
                req.ClientCategory   = loc.TS_Value__c;
                req.ClientCategoryId = Integer.valueOf(loc.TS_ValueId__c);
            }
            if (matterStatus != null) {
                req.ClientSubCategory   = matterStatus.TS_Value__c;
                req.ClientSubCategoryId = Integer.valueOf(matterStatus.TS_ValueId__c);
            }
            
            HttpRequest r = createHttpRequest(
                'POST',
                timesolvBaseUrl + '/client',
                bearerToken,
                JSON.serialize(new List<ClientRequest>{ req })
            );
            HttpResponse res = new Http().send(r);
            Integer code = res.getStatusCode();
            
            if (code == 200 || code == 201) {
                ClientApiResponse api = (ClientApiResponse) JSON.deserialize(res.getBody(), ClientApiResponse.class);
                if (api.Details != null && !api.Details.isEmpty()) {
                    String cid = String.valueOf(api.Details[0].Id);
                    acc.TimeSolv_Client_Id__c = cid;
                    getTSClientId(cid, bearerToken, acc);
                    success = true;
                } else {
                    logRec = TimeSolvIntegrationLogUtil.logWarning(
                        acc.Id,
                        TimeSolvIntegrationLogUtil.INTEGRATION_TYPE_CLIENT,
                        'No details in create response'
                    );
                }
            } else {
                logRec = TimeSolvIntegrationLogUtil.logError(
                    acc.Id,
                    TimeSolvIntegrationLogUtil.INTEGRATION_TYPE_CLIENT,
                    'Create failed ['+code+'] '+res.getBody(),
                    null
                );
            }
        } catch (Exception e) {
            logRec = TimeSolvIntegrationLogUtil.logError(
                acc.Id,
                TimeSolvIntegrationLogUtil.INTEGRATION_TYPE_CLIENT,
                'Exception in callCreateClientAPI',
                e
            );
        }
        return new ClientCreationResult(success, logRec);
    }
    
    private static HttpRequest createHttpRequest(String m, String url, String token, String body) {
        HttpRequest r = new HttpRequest();
        r.setEndpoint(url);
        r.setMethod(m);
        r.setHeader('Content-Type','application/json');
        r.setHeader('Authorization','Bearer '+ token);
        if (body != null) r.setBody(body);
        return r;
    }
    
    public static void getTSClientId(String clientId, String token, Account acc) {
        try {
            HttpRequest r = createHttpRequest(
                'GET',
                timesolvBaseUrl + '/client?ClientId=' + clientId,
                token,
                null
            );
            HttpResponse res = new Http().send(r);
            if (res.getStatusCode() == 200) {
                getApiResponse api = (getApiResponse) JSON.deserialize(res.getBody(), getApiResponse.class);
                if (api.Client != null) {
                    acc.Timesolv_Client_Number__c = api.Client.ClientId;
                    updateClientAPIForClientNumber(acc, clientId, api.Client.ClientId, token);
                } else {
                    TimeSolvIntegrationLogUtil.logWarning(
                        acc.Id,
                        TimeSolvIntegrationLogUtil.INTEGRATION_TYPE_CLIENT,
                        'No client number in GET response'
                    );
                }
            } else {
                TimeSolvIntegrationLogUtil.logError(
                    acc.Id,
                    TimeSolvIntegrationLogUtil.INTEGRATION_TYPE_CLIENT,
                    'GET client failed ['+res.getStatusCode()+'] '+res.getBody(),
                    null
                );
            }
        } catch (Exception e) {
            TimeSolvIntegrationLogUtil.logError(
                acc.Id,
                TimeSolvIntegrationLogUtil.INTEGRATION_TYPE_CLIENT,
                'Exception in getTSClientId',
                e
            );
        }
    }
    
    public static void updateClientAPIForClientNumber(Account acc, String clientId, String clientNumber, String token) {
        try {
            ClientRequest upd = new ClientRequest();
            upd.Id         = Integer.valueOf(clientId);
            upd.ClientName = acc.LastName + ', ' + acc.FirstName + ' ' + clientNumber;
            
            HttpRequest r = createHttpRequest(
                'PUT',
                timesolvBaseUrl + '/client',
                token,
                JSON.serialize(upd)
            );
            HttpResponse res = new Http().send(r);
            Integer sc = res.getStatusCode();
            if (sc != 200 && sc != 201) {
                TimeSolvIntegrationLogUtil.logError(
                    acc.Id,
                    TimeSolvIntegrationLogUtil.INTEGRATION_TYPE_CLIENT,
                    'PUT client failed ['+sc+'] '+res.getBody(),
                    null
                );
            }
        } catch (Exception e) {
            TimeSolvIntegrationLogUtil.logError(
                acc.Id,
                TimeSolvIntegrationLogUtil.INTEGRATION_TYPE_CLIENT,
                'Exception in updateClientAPIForClientNumber',
                e
            );
        }
    }
    
    // JSON‐DTOs
    public class ClientRequest {
        public String  ClientName;
        public String  ClientStatus;
        public String  InvoiceName;
        public Date    OpenDate;
        public String  RateBy;
        public String  GlobalRate;
        public String  PaymentRoutingOption;
        public String  ClientCategory;
        public Integer ClientCategoryId;
        public String  ClientSubCategory;
        public Integer ClientSubCategoryId;
        public Integer Id;
    }
    public class Status       { public Integer ResponseCode; public String Message; }
    public class ClientDetail  { public Integer Id; }
    public class ClientApiResponse { public Status Status; public List<ClientDetail> Details; }
    public class Client        { public Integer Id; public String ClientId; }
    public class getApiResponse { public Status Status; public Client Client; }
}