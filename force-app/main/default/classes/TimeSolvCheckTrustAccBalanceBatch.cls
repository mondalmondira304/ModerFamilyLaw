/**
 * Batch-checks TimeSolv Trust Account balances, syncs them to Salesforce,
 * sends an HTML email, fires Tasks, and logs errors or warnings.
 *
 * @author  Sanders
 * @date    2025-04-30
 */
global without sharing class TimeSolvCheckTrustAccBalanceBatch
     implements Database.Batchable<SObject>,
                Database.AllowsCallouts,
                Database.Stateful {

    public static final Integer SAFE_BATCH_SIZE = 10;

    /* ─── TEST HOOKS ─────────────────────────────────────────────── */
    @TestVisible private static String  testBaseUrl;
    @TestVisible private static String  testCcEmails;

    /* ─── CACHED CONFIG ──────────────────────────────────────────── */
    private static String  cachedBaseUrl;
    private static String  cachedCcEmails;

    /* Intake-Team queue cache */
    @TestVisible private static Id      cachedIntakeQueueId;

    public static Id runBatch(Integer batchSize) {
        if (batchSize == null || batchSize <= 0) {
            batchSize = SAFE_BATCH_SIZE;
        }
        return Database.executeBatch(
            new TimeSolvCheckTrustAccBalanceBatch(),
            batchSize
        );
    }

    /* ─── CONFIG: Endpoint URL ───────────────────────────────────── */
    private static String getBaseUrl() {
        if (Test.isRunningTest() && testBaseUrl != null) {
            return testBaseUrl;
        }
        if (cachedBaseUrl == null) {
            List<TimeSolv_Integration_Configuration__mdt> cfgs = [
                SELECT Endpoint_URL__c
                  FROM TimeSolv_Integration_Configuration__mdt
                 WHERE Label = 'Production'
                 LIMIT 1
            ];
            String prodUrl = (!cfgs.isEmpty()) ? cfgs[0].Endpoint_URL__c : '';
            cachedBaseUrl = (Test.isRunningTest() || String.isBlank(prodUrl))
                          ? 'https://dummy.salesforcelocal'
                          : prodUrl;
        }
        return cachedBaseUrl;
    }

    /* ─── CONFIG: CC Email List ──────────────────────────────────── */
    private static String getCcEmails() {
        if (Test.isRunningTest() && testCcEmails != null) {
            return testCcEmails;
        }
        if (cachedCcEmails == null) {
            List<TimeSolv_Integration_Configuration__mdt> cfgs = [
                SELECT Email_CC_List__c
                  FROM TimeSolv_Integration_Configuration__mdt
                 WHERE Label = 'Production'
                 LIMIT 1
            ];
            cachedCcEmails = (!cfgs.isEmpty()) ? cfgs[0].Email_CC_List__c : '';
        }
        return cachedCcEmails;
    }

    /* ─── FETCH INTAKE-QUEUE ID ─────────────────────────────────── */
    private static Id getIntakeQueueId() {
        if (cachedIntakeQueueId == null) {
            List<Group> groups = [
                SELECT Id
                  FROM Group
                 WHERE DeveloperName = 'Intake_Team'
                   AND Type = 'Queue'
                 LIMIT 1
            ];
            cachedIntakeQueueId = (!groups.isEmpty()) ? groups[0].Id : null;
        }
        return cachedIntakeQueueId;
    }

    /* ─── STATE ──────────────────────────────────────────────────── */
    private List<TimeSolv_Integration_Log__c> logBuffer = new List<TimeSolv_Integration_Log__c>();

    /* ─── BATCH START ────────────────────────────────────────────── */
    global Database.QueryLocator start(Database.BatchableContext bc) {
        return Database.getQueryLocator([
           SELECT
                Id,
                echosign_dev1__Account__c,
                echosign_dev1__Account__r.TimeSolv_Client_Id__c,
                echosign_dev1__Account__r.Timesolv_TrustAccount_Id__c,
                echosign_dev1__Account__r.Timesolv_TrustAccount_Balance__c,
                echosign_dev1__Account__r.Timesolv_TrustAccount_Replenish_Below__c,
                echosign_dev1__Account__r.Timesolv_TrustAccount_Replenish_To__c,
                echosign_dev1__Account__r.Credit_Decision__c,
                echosign_dev1__Account__r.Credit_Check_Complete__c,
                echosign_dev1__Account__r.Quoted_Retainer_Amount__c,
                echosign_dev1__Account__r.Consultation_Status__c
             FROM echosign_dev1__SIGN_Agreement__c
            WHERE echosign_dev1__Status__c = 'Signed'
              AND (NOT Name LIKE '%Family Law CC Authorization%')
              AND echosign_dev1__Account__r.IsPersonAccount = true
              AND echosign_dev1__Account__r.RecordType.DeveloperName = 'Potential_Client'
              AND (
                     echosign_dev1__Account__r.Consultation_Status__c = NULL
                  OR echosign_dev1__Account__r.Consultation_Status__c != 'Not Going To Hire'
                  )
              AND (
                     // 1) never processed
                     echosign_dev1__Account__r.Timesolv_TrustAccount_Balance__c = NULL
                  OR // 2) needs replenishment
                     (
                         echosign_dev1__Account__r.Timesolv_TrustAccount_Balance__c = 0
                     AND echosign_dev1__Account__r.Timesolv_TrustAccount_Replenish_Below__c > 0
                     AND echosign_dev1__Account__r.Timesolv_TrustAccount_Replenish_To__c   > 0
                     )
                  OR // 3) explicit Gold Offer (regardless of thresholds), still zero balance
                     (
                         echosign_dev1__Account__r.Credit_Decision__c LIKE 'Gold%'
                     AND echosign_dev1__Account__r.Timesolv_TrustAccount_Balance__c = 0
                     )
                  )
        ]);
    }

    /* ─── BATCH EXECUTE ──────────────────────────────────────────── */
    global void execute(
        Database.BatchableContext bc,
        List<echosign_dev1__SIGN_Agreement__c> scope
    ) {
        // 1) Map Account → TrustId & ClientId
        Map<Id,String> acctToTrust  = new Map<Id,String>();
        Map<Id,String> acctToClient = new Map<Id,String>();
        for (echosign_dev1__SIGN_Agreement__c agr : scope) {
            Id acctId = agr.echosign_dev1__Account__c;
            if (acctId == null) continue;
            Account a = agr.echosign_dev1__Account__r;
            if (a == null || a.Consultation_Status__c == 'Not Going To Hire') continue;
            if (a.Timesolv_TrustAccount_Id__c != null) {
                acctToTrust.put(acctId, a.Timesolv_TrustAccount_Id__c);
            }
            if (String.isNotBlank(a.TimeSolv_Client_Id__c)) {
                acctToClient.put(acctId, a.TimeSolv_Client_Id__c);
            }
        }
        if (acctToTrust.isEmpty()) {
            return;
        }

        // 2) Fetch balances
        Map<Id,TrustAccountBalance> respMap = new Map<Id,TrustAccountBalance>();
        Integer slotsLeft = Limits.getLimitCallouts() - Limits.getCallouts();
        for (Id acctId : acctToTrust.keySet()) {
            if (slotsLeft <= 0) {
                bufferWarning(acctId, 'Skipped – callout limit hit');
                continue;
            }
            TrustAccountBalanceResponse r =
                fetchTrustAccountBalance(acctToTrust.get(acctId));
            slotsLeft = Limits.getLimitCallouts() - Limits.getCallouts();
            if (r?.TrustAccountBalance != null) {
                respMap.put(acctId, r.TrustAccountBalance);
            } else {
                bufferWarning(acctId, 'Balance retrieval failed');
            }
        }

        // 3) Activate clients if positive balance
        for (Id acctId : respMap.keySet()) {
            Decimal bal = respMap.get(acctId).Balance == null
                          ? 0 : respMap.get(acctId).Balance;
            if (bal > 0 && acctToClient.containsKey(acctId)) {
                Boolean ok = updateClientStatusToActive(
                    acctToClient.get(acctId), acctId);
                if (!ok) bufferError(acctId, 'Client activation failed');
            }
        }

        // 4) Persist balances + thresholds, then notify & tasks
        if (!respMap.isEmpty()) {
            List<Account> updates = new List<Account>();
            for (Id acctId : respMap.keySet()) {
                TrustAccountBalance tb = respMap.get(acctId);
                Decimal belowAmt = tb.ReplenishBelow == null ? 0 : tb.ReplenishBelow;
                Decimal toAmt    = tb.ReplenishTo    == null ? 0 : tb.ReplenishTo;
                Decimal apiBal   = tb.Balance;
                Decimal balToSet = (apiBal == null && belowAmt == 0 && toAmt == 0)
                                  ? 0 : apiBal;
                updates.add(new Account(
                    Id                                      = acctId,
                    Timesolv_TrustAccount_Replenish_Below__c= belowAmt,
                    Timesolv_TrustAccount_Replenish_To__c   = toAmt,
                    Timesolv_TrustAccount_Balance__c        = balToSet
                ));
            }

            Database.SaveResult[] results = Database.update(updates, false);
            List<Id> succeeded = new List<Id>();
            for (Integer i = 0; i < results.size(); i++) {
                if (results[i].isSuccess()) {
                    succeeded.add(updates[i].Id);
                } else {
                    bufferError(
                      updates[i].Id,
                      'Update failed: ' +
                        String.join(
                          getErrorMessages(results[i].getErrors()), '; '
                        )
                    );
                }
            }

            invokeNotificationsAndTasks(respMap, succeeded);
        }
    }

    /* ─── BATCH FINISH ───────────────────────────────────────────── */
    global void finish(Database.BatchableContext bc) {
        if (!logBuffer.isEmpty()) {
            insert logBuffer;
        }
        TimeSolvIntegrationLogUtil.savePendingLogs();
    }

    /* ─── ORG-WIDE EMAIL ────────────────────────────────────────── */
    private static Id orgWideEmailId;
    private static Boolean orgWideQueried = false;

    /**
     * @return the Org-Wide Email Address Id for reception@modernfamilylaw.com
     */
    private static Id getOrgWideEmailId() {
        if (!orgWideQueried) {
            List<OrgWideEmailAddress> owes = [
                SELECT Id
                  FROM OrgWideEmailAddress
                 WHERE Address = 'reception@modernfamilylaw.com'
                 LIMIT 1
            ];
            orgWideEmailId = (!owes.isEmpty()) ? owes[0].Id : null;
            orgWideQueried = true;
        }
        return orgWideEmailId;
    }

    /* ─── NOTIFICATIONS & TASKS ──────────────────────────────────── */
    private void invokeNotificationsAndTasks(
        Map<Id,TrustAccountBalance> respMap,
        List<Id> acctIds
    ) {
        if (acctIds.isEmpty()) return;

        Set<Id> accountsWithGoldOfferTask       = new Set<Id>();
        Set<Id> accountsWithIntakeQueueTask     = new Set<Id>();

        Id intakeQueueId = getIntakeQueueId();

        for (Task t : [
            SELECT WhatId, Subject, OwnerId
              FROM Task
             WHERE WhatId IN :acctIds
               AND (
                     Subject = 'Trust Account has Gold offer: no funds'
                  OR (
                       Subject = 'Gold Offer: Intake Team, Please manually send Credit Card Authorization form'
                     AND OwnerId = :intakeQueueId
                     )
                   )
        ]) {
            if (t.Subject == 'Trust Account has Gold offer: no funds') {
                accountsWithGoldOfferTask.add(t.WhatId);
            } else if (
                t.Subject == 'Gold Offer: Intake Team, Please manually send Credit Card Authorization form'
                && t.OwnerId == intakeQueueId
            ) {
                accountsWithIntakeQueueTask.add(t.WhatId);
            }
        }

        List<Account> accts = [
            SELECT Id, Name,
                   Responsible_Attorney__r.Email,
                   Responsible_Attorney__r.Name,
                   Responsible_Paralegal__r.Email,
                   Responsible_Paralegal__r.Name,
                   Credit_Decision__c, Credit_Check_Complete__c, Quoted_Retainer_Amount__c
              FROM Account
             WHERE Id IN :acctIds
        ];

        List<Messaging.SingleEmailMessage> emails = new List<Messaging.SingleEmailMessage>();
        List<Task>                         tasks  = new List<Task>();

        for (Account acc : accts) {
            TrustAccountBalance tb = respMap.get(acc.Id);
            Decimal bal      = ht(tb.Balance);
            Decimal belowAmt = ht(tb.ReplenishBelow);
            Decimal toAmt    = ht(tb.ReplenishTo);

            Boolean hasConfig = (belowAmt > 0 && toAmt > 0);
            Boolean goldOffer = isGoldDecision(acc);
            Boolean goldZero  = (goldOffer && bal == 0);
            Boolean needRepl  = (hasConfig && bal <= belowAmt);

            /* — EMAIL for Funded / Replenish — */
            if (bal > 0 && acc.Responsible_Attorney__r != null
                        && acc.Responsible_Attorney__r.Email != null) {
                String amtFmt = bal.setScale(2).format();
                String link   = URL.getOrgDomainUrl().toExternalForm() + '/' + acc.Id;

                String atnFirst = '';
                if (String.isNotBlank(acc.Responsible_Attorney__r.Name)) {
                    String[] atn = acc.Responsible_Attorney__r.Name.split(' ');
                    atnFirst = atn[0];
                }
                String plFirst = '';
                if (acc.Responsible_Paralegal__r != null
                    && String.isNotBlank(acc.Responsible_Paralegal__r.Name)) {
                    String[] pl = acc.Responsible_Paralegal__r.Name.split(' ');
                    plFirst = pl[0];
                }
                String greeting = 'Dear ' + atnFirst +
                                  (String.isNotBlank(plFirst) ? ' / ' + plFirst : '') + ',';

                Messaging.SingleEmailMessage m = new Messaging.SingleEmailMessage();
                Id oweId = getOrgWideEmailId();
                if (oweId != null) {
                    m.setOrgWideEmailAddressId(oweId);
                }
                m.setToAddresses(new List<String>{
                    acc.Responsible_Attorney__r.Email
                });

                /* ─ CC LIST: Paralegal + values from CMDT ─ */
                List<String> ccList = new List<String>();
                if (acc.Responsible_Paralegal__r != null &&
                    acc.Responsible_Paralegal__r.Email != null) {
                    ccList.add(acc.Responsible_Paralegal__r.Email);
                }
                String cfgCc = getCcEmails();
                if (String.isNotBlank(cfgCc)) {
                    for (String addr : cfgCc.split('[;,]')) {
                        String trimmed = addr.trim();
                        if (String.isNotBlank(trimmed)) ccList.add(trimmed);
                    }
                }
                if (!ccList.isEmpty()) {
                    m.setCcAddresses(ccList);
                }

                m.setSubject('Intake Task - PC ready to convert to Client');

                String safeName = acc.Name != null ? acc.Name.escapeHtml4() : '';

                String html =
                    '<html><body>' +
                    //'<p style="color:#333;">' + greeting + '</p>' +
                    '<p style="color:#333;">' +
                    'The PC, <b style="color:#555;">' + safeName + '</b>, has signed the Fee Agreement ' +
                    'and paid the initial deposit of <b style="color:#555;">$' + amtFmt + '</b> in full.' +
                    '</p>' +
                    '<p style="color:#333;">' +
                    'With all onboarding steps completed, they are ready to be officially ' +
                    'converted to a new client file and transitioned to the appropriate team.' +
                    '</p>' +
                    '<p style="color:#333;">' +
                    'Thank you for your continued collaboration in ensuring a smooth ' +
                    'onboarding process.' +
                    '</p>' +
                    '<p style="color:#333;">' +
                    'Link to PC Account: ' +
                    '<a href="' + link + '">' + link + '</a>' +
                    '</p>' +
                    '<p style="color:#333;">Thank you,<br/>MFL Team</p>' +
                    '</body></html>';

                m.setHtmlBody(html);
                emails.add(m);
            }

            /* — TASK: Funded — */
            if (bal > 0) {
                tasks.add(new Task(
                    WhatId       = acc.Id,
                    Subject      = 'Trust Account Funded: $' + bal.setScale(2).format(),
                    Status       = 'Completed',
                    Priority     = 'Normal',
                    Type         = 'Trust Account',
                    ActivityDate = Date.today(),
                    Description  = 'Balance updated to $' + bal.setScale(2).format()
                ));

            /* — TASK: Gold Offer — */
            } else if (goldZero) {
                if (!accountsWithGoldOfferTask.contains(acc.Id)) {
                    tasks.add(new Task(
                        WhatId       = acc.Id,
                        Subject      = 'Trust Account has Gold offer: no funds',
                        Status       = 'Completed',
                        Priority     = 'Normal',
                        Type         = 'Trust Account',
                        ActivityDate = Date.today(),
                        Description  = 'Account on Gold Offer plan; Balance=0'
                    ));
                }

                if (intakeQueueId != null && !accountsWithIntakeQueueTask.contains(acc.Id)) {
                    tasks.add(new Task(
                        WhatId       = acc.Id,
                        OwnerId      = intakeQueueId,
                        Subject      = 'Gold Offer: Intake Team, Please manually send Credit Card Authorization form',
                        Status       = 'Not Started',
                        Priority     = 'High',
                        Type         = 'Trust Account',
                        ActivityDate = Date.today(),
                        Description  = 'Client has Gold Offer – Intake Team please manually send credit-card authorization form to client.'
                    ));
                }
            }
        }

        if (!emails.isEmpty() && !Test.isRunningTest()) {
            try {
                Messaging.sendEmail(emails);
            } catch (Exception e) {
                bufferError(null, 'Email send failed: ' + e.getMessage());
            }
        }
        if (!tasks.isEmpty()) {
            Database.SaveResult[] taskResults = Database.insert(tasks, false);
            for (Integer i = 0; i < taskResults.size(); i++) {
                if (!taskResults[i].isSuccess()) {
                    bufferError(
                        tasks[i].WhatId,
                        'Task insert failed: ' +
                        String.join(getErrorMessages(taskResults[i].getErrors()), '; ')
                    );
                }
            }
        }
    }

    /* ─── STATIC CALL-OUT HELPERS ────────────────────────────────── */
    private static TrustAccountBalanceResponse fetchTrustAccountBalance(String trustId) {
        try {
            HttpRequest req = new HttpRequest();
            req.setEndpoint(
                getBaseUrl() +
                '/trustAccountBalance?TrustAccountId=' +
                EncodingUtil.urlEncode(trustId,'UTF-8')
            );
            req.setMethod('GET');
            req.setTimeout(30000);
            req.setHeader('Authorization',
                'Bearer ' + TimeSolvIntegrationTokenUtil.getBearerToken());
            HttpResponse res = new Http().send(req);
            if (res.getStatusCode() == 200) {
                return (TrustAccountBalanceResponse)
                       JSON.deserialize(res.getBody(),
                                        TrustAccountBalanceResponse.class);
            }
        } catch (Exception e) {
            System.debug(LoggingLevel.ERROR,
                'fetchTrustAccountBalance failed for TrustId=' + trustId + ': ' + e.getMessage());
        }
        return null;
    }

    private static Boolean updateClientStatusToActive(String clientId, Id acctId) {
        try {
            HttpRequest req = new HttpRequest();
            req.setEndpoint(getBaseUrl() + '/client');
            req.setMethod('PUT');
            req.setTimeout(30000);
            req.setHeader('Content-Type','application/json');
            req.setHeader('Authorization',
                'Bearer ' + TimeSolvIntegrationTokenUtil.getBearerToken());
            req.setBody(JSON.serialize(
                new ClientRequest(Integer.valueOf(clientId),'Active')));
            HttpResponse res = new Http().send(req);
            return res.getStatusCode() == 200
                || res.getStatusCode() == 201;
        } catch (Exception e) {
            System.debug(LoggingLevel.ERROR,
                'updateClientStatusToActive failed for ClientId=' + clientId + ': ' + e.getMessage());
        }
        return false;
    }

    /* ─── BUFFERED LOGGING ──────────────────────────────────────── */
    private void bufferWarning(Id acctId, String msg) {
        TimeSolv_Integration_Log__c l = TimeSolvIntegrationLogUtil.logWarning(
            acctId,
            TimeSolvIntegrationLogUtil.INTEGRATION_TYPE_CHECK_TRUST_ACC,
            msg
        );
        logBuffer.add(l);
    }

    private void bufferError(Id acctId, String msg) {
        TimeSolv_Integration_Log__c l = TimeSolvIntegrationLogUtil.logError(
            acctId,
            TimeSolvIntegrationLogUtil.INTEGRATION_TYPE_CHECK_TRUST_ACC,
            msg,
            null
        );
        logBuffer.add(l);
    }

    private List<String> getErrorMessages(List<Database.Error> errs) {
        List<String> out = new List<String>();
        for (Database.Error e : errs) {
            out.add(e.getStatusCode() + ': ' + e.getMessage());
        }
        return out;
    }

    /* ─── DTOs ───────────────────────────────────────────────────── */
    global class TrustAccountBalanceResponse {
        public TrustAccountBalance TrustAccountBalance;
    }
    global class TrustAccountBalance {
        public Decimal Balance;
        public Decimal ReplenishBelow;
        public Decimal ReplenishTo;
    }
    global class ClientRequest {
        public Integer Id;
        public String  ClientStatus;
        ClientRequest(Integer i, String s) {
            Id = i;
            ClientStatus = s;
        }
    }

    /* ─── UTIL ──────────────────────────────────────────────────── */
    private static Decimal ht(Decimal d) {
        return (d == null) ? 0 : d;
    }

    private static Boolean isGoldDecision(Account a) {
        return a != null
            && a.Credit_Decision__c != null
            && a.Credit_Decision__c.startsWith('Gold');
    }
}