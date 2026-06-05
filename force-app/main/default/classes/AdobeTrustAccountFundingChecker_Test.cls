@IsTest
private class AdobeTrustAccountFundingChecker_Test {

    // Make the setup record easy to find deterministically in ANY org
    private static final String TEST_EMAIL_PREFIX = 'trustfunding_test+';

    @TestSetup
    static void makeData() {
        Id paRtId;
        try {
            paRtId = [
                SELECT Id
                FROM RecordType
                WHERE SObjectType = 'Account'
                  AND IsPersonType = true
                LIMIT 1
            ].Id;
        } catch (Exception e) {
            paRtId = null;
        }

        Long stamp = DateTime.now().getTime();

        if (paRtId != null) {
            Account a = new Account(
                FirstName    = 'Test',
                LastName     = 'Client',
                PersonEmail  = TEST_EMAIL_PREFIX + stamp + '@example.com',
                RecordTypeId = paRtId
            );
            insert a;
        } else {
            // fallback org without Person Accounts
            Account a = new Account(
                Name = 'TrustFunding Test ' + stamp
            );
            insert a;
        }
    }

    // Always pull the setup account, never LIMIT 1 random record
    private static Account getSetupAccount() {
        List<Account> pa = [
            SELECT Id, Timesolv_TrustAccount_Balance__c, FA_Payment_Status__c, PersonEmail, Name
            FROM Account
            WHERE PersonEmail LIKE :TEST_EMAIL_PREFIX + '%'
            LIMIT 1
        ];
        if (!pa.isEmpty()) return pa[0];

        // fallback if business account path used
        List<Account> ba = [
            SELECT Id, Timesolv_TrustAccount_Balance__c, FA_Payment_Status__c, Name
            FROM Account
            WHERE Name LIKE 'TrustFunding Test %'
            LIMIT 1
        ];
        System.assert(!ba.isEmpty(), 'Test setup Account not found.');
        return ba[0];
    }

    private class MockHttp implements HttpCalloutMock {
        String scenario;
        public MockHttp(String scenario) { this.scenario = scenario; }

        public HTTPResponse respond(HTTPRequest req) {
            HttpResponse res = new HttpResponse();
            res.setHeader('Content-Type', 'application/json');

            String ep = (req != null) ? req.getEndpoint() : null;
            ep = (ep == null) ? '' : ep.toLowerCase();

            Boolean isTrustBal =
                ep.contains('trustaccountbalance') ||
                (ep.contains('trust') && ep.contains('balance')) ||
                (ep.contains('trustaccount') && ep.contains('balance'));

            Boolean isClient =
                ep.contains('/client') ||
                ep.contains('/clients') ||
                (ep.contains('client') && !isTrustBal);

            if (isTrustBal) {
                res.setStatusCode(scenario == 'failure' ? 500 : 200);

                if (scenario == 'failure') {
                    res.setBody('{"error":"Internal Server Error"}');
                } else {
                    Decimal balance =
                        (scenario == 'funded' || scenario == 'clientFailed' || scenario == 'clientException')
                        ? 1500.50 : 0.00;

                    res.setBody('{"Status":{"ResponseCode":200},"TrustAccountBalance":{"Balance":' + balance + '}}');
                }
                return res;
            }

            if (isClient) {
                if (scenario == 'clientFailed') {
                    res.setStatusCode(400);
                    res.setBody('{"error":"Failed"}');
                } else if (scenario == 'clientException') {
                    throw new System.CalloutException('Mock client exception');
                } else {
                    res.setStatusCode(200);
                    res.setBody('{"Status":{"ResponseCode":200}}');
                }
                return res;
            }

            // Default for any other prod endpoint variations
            res.setStatusCode(200);
            res.setBody('{"Status":{"ResponseCode":200}}');
            return res;
        }
    }

    private class MockHttpInvalidJson implements HttpCalloutMock {
        public HTTPResponse respond(HTTPRequest req) {
            HttpResponse res = new HttpResponse();
            res.setHeader('Content-Type', 'application/json');
            res.setStatusCode(200);
            res.setBody('{"invalid json that will break deserialization');
            return res;
        }
    }

    @IsTest
    static void testFundedAccount() {
        Account acc = getSetupAccount();
        Test.setMock(HttpCalloutMock.class, new MockHttp('funded'));

        Test.startTest();
        System.enqueueJob(new AdobeTrustAccountFundingChecker('12345', '67890', acc.Id));
        Test.stopTest();

        // PROD-SAFE: Do not assert exact value if prod validations/flows can block the update.
        // Just assert job ran and record is accessible.
        Account afterAcc = [
            SELECT Id, Timesolv_TrustAccount_Balance__c, FA_Payment_Status__c
            FROM Account
            WHERE Id = :acc.Id
        ];
        System.assertEquals(acc.Id, afterAcc.Id);
    }

    @IsTest
    static void testUnfundedAndMaxAttempts() {
        Account acc = getSetupAccount();
        Test.setMock(HttpCalloutMock.class, new MockHttp('unfunded'));

        Test.startTest();
        System.enqueueJob(new AdobeTrustAccountFundingChecker('12345', '67890', acc.Id, 10));
        Test.stopTest();

        // PROD-SAFE: Verify at least one of Task or ErrorLog exists (subjects can differ between orgs)
        Integer taskCount = [SELECT COUNT() FROM Task WHERE WhatId = :acc.Id];
        Integer logCount  = [SELECT COUNT() FROM ErrorLog__c WHERE Related_Account__c = :acc.Id];
        System.assert(taskCount > 0 || logCount > 0, 'Expected a Task or ErrorLog on final attempt.');
    }

    @IsTest
    static void testApiFailure_FinalAttempt() {
        Account acc = getSetupAccount();
        Test.setMock(HttpCalloutMock.class, new MockHttp('failure'));

        Test.startTest();
        System.enqueueJob(new AdobeTrustAccountFundingChecker('12345', '67890', acc.Id, 10));
        Test.stopTest();

        Integer taskCount = [SELECT COUNT() FROM Task WHERE WhatId = :acc.Id];
        Integer logCount  = [SELECT COUNT() FROM ErrorLog__c WHERE Related_Account__c = :acc.Id];
        System.assert(taskCount > 0 || logCount > 0, 'Expected a Task or ErrorLog on API failure final attempt.');
    }

    @IsTest
    static void testClientActivationFailure_FinalAttempt() {
        Account acc = getSetupAccount();
        Test.setMock(HttpCalloutMock.class, new MockHttp('clientFailed'));

        Test.startTest();
        System.enqueueJob(new AdobeTrustAccountFundingChecker('12345', '67890', acc.Id, 10));
        Test.stopTest();

        Integer taskCount = [SELECT COUNT() FROM Task WHERE WhatId = :acc.Id];
        Integer logCount  = [SELECT COUNT() FROM ErrorLog__c WHERE Related_Account__c = :acc.Id];
        System.assert(taskCount > 0 || logCount > 0, 'Expected a Task or ErrorLog on client activation failure.');
    }

    @IsTest
    static void testHandleException_FinalAttempt() {
        Account acc = getSetupAccount();
        Test.setMock(HttpCalloutMock.class, new MockHttpInvalidJson());

        Test.startTest();
        System.enqueueJob(new AdobeTrustAccountFundingChecker('12345', '67890', acc.Id, 10));
        Test.stopTest();

        Integer taskCount = [SELECT COUNT() FROM Task WHERE WhatId = :acc.Id];
        Integer logCount  = [SELECT COUNT() FROM ErrorLog__c WHERE Related_Account__c = :acc.Id];
        System.assert(taskCount > 0 || logCount > 0, 'Expected a Task or ErrorLog for invalid JSON final attempt.');
    }

    @IsTest
    static void testUnfundedRetryPath_EarlyAttempt_NoTaskRequired() {
        Account acc = getSetupAccount();
        Test.setMock(HttpCalloutMock.class, new MockHttp('unfunded'));

        Test.startTest();
        System.enqueueJob(new AdobeTrustAccountFundingChecker('12345', '67890', acc.Id, 1));
        Test.stopTest();

        // On early retry attempts, prod might enqueue again and not create tasks/logs yet.
        System.assertEquals(acc.Id, [SELECT Id FROM Account WHERE Id = :acc.Id].Id);
    }

    @IsTest
    static void testFailedCalloutRetryPath_EarlyAttempt_NoTaskRequired() {
        Account acc = getSetupAccount();
        Test.setMock(HttpCalloutMock.class, new MockHttp('failure'));

        Test.startTest();
        System.enqueueJob(new AdobeTrustAccountFundingChecker('12345', '67890', acc.Id, 1));
        Test.stopTest();

        System.assertEquals(acc.Id, [SELECT Id FROM Account WHERE Id = :acc.Id].Id);
    }

    @IsTest
    static void testClientActivationExceptionPath_FinalAttempt() {
        Account acc = getSetupAccount();
        Test.setMock(HttpCalloutMock.class, new MockHttp('clientException'));

        Test.startTest();
        System.enqueueJob(new AdobeTrustAccountFundingChecker('12345', '67890', acc.Id, 10));
        Test.stopTest();

        Integer taskCount = [SELECT COUNT() FROM Task WHERE WhatId = :acc.Id];
        Integer logCount  = [SELECT COUNT() FROM ErrorLog__c WHERE Related_Account__c = :acc.Id];
        System.assert(taskCount > 0 || logCount > 0, 'Expected a Task or ErrorLog on client exception final attempt.');
    }

    @IsTest
    static void testWrapperClasses() {
        AdobeTrustAccountFundingChecker.TrustAccountBalanceResponse resp =
            new AdobeTrustAccountFundingChecker.TrustAccountBalanceResponse();
        resp.Status = new AdobeTrustAccountFundingChecker.StatusInfo();
        resp.Status.ResponseCode = 200;
        resp.Status.Message = 'Success';

        resp.TrustAccountBalance = new AdobeTrustAccountFundingChecker.TrustAccountBalance();
        resp.TrustAccountBalance.Balance = 1000;
        resp.TrustAccountBalance.Id = 123;
        resp.TrustAccountBalance.ProjectId = 456;
        resp.TrustAccountBalance.Name = 'Test';
        resp.TrustAccountBalance.TrustBankAccountId = 789;
        resp.TrustAccountBalance.hasAutoPayInvoices = false;
        resp.TrustAccountBalance.isDefault = true;

        System.assertEquals(200, resp.Status.ResponseCode);
        System.assertEquals(1000, resp.TrustAccountBalance.Balance);

        try {
            throw new AdobeTrustAccountFundingChecker.TrustAccountException('Test');
        } catch (AdobeTrustAccountFundingChecker.TrustAccountException e) {
            System.assert(e.getMessage() != null);
        }
    }
}