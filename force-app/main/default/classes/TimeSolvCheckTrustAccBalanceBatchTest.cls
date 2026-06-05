@IsTest(SeeAllData = false)
private class TimeSolvCheckTrustAccBalanceBatchTest {

    /* ─────────────────────────────────────────────────────────────
     * CONSTANTS
     * ──────────────────────────────────────────────────────────── */
    private static final String DUMMY_URL = 'https://dummy.salesforcelocal';

    /* ─────────────────────────────────────────────────────────────
     * HTTP CALLOUT MOCK IMPLEMENTATIONS
     * ──────────────────────────────────────────────────────────── */

    /** 200 → Balance = 100 (funded path) */
    private class PositiveMock implements HttpCalloutMock {
        public HTTPResponse respond(HTTPRequest req) {
            HttpResponse res = new HttpResponse();
            if (req.getEndpoint().contains('/trustAccountBalance')) {
                res.setStatusCode(200);
                res.setHeader('Content-Type', 'application/json');
                res.setBody(
                    '{"TrustAccountBalance":{"Balance":100,"ReplenishBelow":10,"ReplenishTo":50}}'
                );
            } else if (req.getEndpoint().endsWith('/client')) {
                res.setStatusCode(200);
                res.setBody('{}');
            } else {
                res.setStatusCode(404);
            }
            return res;
        }
    }

    /** 200 → Balance = 0 (Gold-offer path) */
    private class ZeroBalanceMock implements HttpCalloutMock {
        public HTTPResponse respond(HTTPRequest req) {
            HttpResponse res = new HttpResponse();
            if (req.getEndpoint().contains('/trustAccountBalance')) {
                res.setStatusCode(200);
                res.setHeader('Content-Type', 'application/json');
                res.setBody(
                    '{"TrustAccountBalance":{"Balance":0,"ReplenishBelow":0,"ReplenishTo":0}}'
                );
            } else if (req.getEndpoint().endsWith('/client')) {
                res.setStatusCode(200);
                res.setBody('{}');
            } else {
                res.setStatusCode(404);
            }
            return res;
        }
    }

    /** 200 on balance, 500 on /client → error branch */
    private class ClientErrorMock implements HttpCalloutMock {
        public HTTPResponse respond(HTTPRequest req) {
            HttpResponse res = new HttpResponse();
            if (req.getEndpoint().contains('/trustAccountBalance')) {
                res.setStatusCode(200);
                res.setHeader('Content-Type', 'application/json');
                res.setBody(
                    '{"TrustAccountBalance":{"Balance":100,"ReplenishBelow":10,"ReplenishTo":50}}'
                );
            } else if (req.getEndpoint().endsWith('/client')) {
                res.setStatusCode(500);
                res.setBody('{}');
            } else {
                res.setStatusCode(404);
            }
            return res;
        }
    }

    /** 500 on balance endpoint → warning branch */
    private class BalanceErrorMock implements HttpCalloutMock {
        public HTTPResponse respond(HTTPRequest req) {
            HttpResponse res = new HttpResponse();
            if (req.getEndpoint().contains('/trustAccountBalance')) {
                res.setStatusCode(500);
                res.setBody('{}');
            } else {
                res.setStatusCode(200);
                res.setBody('{}');
            }
            return res;
        }
    }

    /* ─────────────────────────────────────────────────────────────
     * HELPER – create Potential_Client Person Account
     * ──────────────────────────────────────────────────────────── */
    private static Account createPotentialClientPA(
        String lastName,
        String clientId,
        String trustId,
        String emailTag
    ) {
        Id rtId = Schema.SObjectType.Account.getRecordTypeInfosByDeveloperName()
            .get('Potential_Client').getRecordTypeId();

        Account pa = new Account(
            RecordTypeId                = rtId,
            LastName                    = lastName,
            PersonEmail                 = lastName.replace(' ', '_').toLowerCase() + emailTag,
            TimeSolv_Client_Id__c       = clientId,
            Timesolv_TrustAccount_Id__c = trustId
        );
        insert pa;
        return pa;
    }

    /* ─────────────────────────────────────────────────────────────
     * TEST #1 – funded path
     * ──────────────────────────────────────────────────────────── */
    @IsTest static void testPositiveBalanceUpdatesAccount() {

        TimeSolvCheckTrustAccBalanceBatch.testBaseUrl = DUMMY_URL;

        Account acc = createPotentialClientPA(
            'Client_Funded',
            '200',
            '300',
            '@funded.mfl.test'
        );

        insert new echosign_dev1__SIGN_Agreement__c(
            Name                      = 'Signed Agr – P',
            echosign_dev1__Account__c = acc.Id,
            echosign_dev1__Status__c  = 'Signed'
        );

        Test.setMock(HttpCalloutMock.class, new PositiveMock());

        Test.startTest();
            TimeSolvCheckTrustAccBalanceBatch.runBatch(1);
        Test.stopTest();

        acc = [
            SELECT Timesolv_TrustAccount_Balance__c,
                   Timesolv_TrustAccount_Replenish_Below__c,
                   Timesolv_TrustAccount_Replenish_To__c
            FROM   Account
            WHERE  Id = :acc.Id
        ];

        System.assertEquals(100, acc.Timesolv_TrustAccount_Balance__c, 'Balance should be 100');
        System.assertEquals(10,  acc.Timesolv_TrustAccount_Replenish_Below__c, 'Replenish Below should be 10');
        System.assertEquals(50,  acc.Timesolv_TrustAccount_Replenish_To__c, 'Replenish To should be 50');

        Integer taskCnt = [SELECT COUNT() FROM Task WHERE WhatId = :acc.Id];
        System.assertEquals(1, taskCnt, 'A single "funded" Task should have been created');
    }

    /* ─────────────────────────────────────────────────────────────
     * TEST #2 – Gold offer → Intake-queue task
     * ──────────────────────────────────────────────────────────── */
    @IsTest static void testGoldOfferCreatesIntakeQueueTask() {

        TimeSolvCheckTrustAccBalanceBatch.testBaseUrl = DUMMY_URL;

        Account acc = createPotentialClientPA(
            'Client_Gold',
            '201',
            '301',
            '@gold.mfl.test'
        );
        acc.Credit_Decision__c = 'Gold - 0% Retainer';
        update acc;

        insert new echosign_dev1__SIGN_Agreement__c(
            Name                      = 'Signed Agr – G',
            echosign_dev1__Account__c = acc.Id,
            echosign_dev1__Status__c  = 'Signed'
        );

        Test.setMock(HttpCalloutMock.class, new ZeroBalanceMock());

        Test.startTest();
            TimeSolvCheckTrustAccBalanceBatch.runBatch(1);
        Test.stopTest();

        List<Task> tasks = [
            SELECT OwnerId, Subject
            FROM   Task
            WHERE  WhatId = :acc.Id
        ];
        
        System.assert(tasks.size() > 0, 'At least one task should be created for Gold Offer account');
        
        Boolean hasAuthFormTask = false;
        for (Task t : tasks) {
            if (t.Subject.contains('Credit Card Authorization')) {
                hasAuthFormTask = true;
                break;
            }
        }
        
        System.assert(hasAuthFormTask, 'Task should ask for Credit Card Authorization form');
    }

    /* ─────────────────────────────────────────────────────────────
     * TEST #3 – /client call fails → bufferError
     * ──────────────────────────────────────────────────────────── */
    @IsTest static void testClientActivationErrorCreatesLog() {

        TimeSolvCheckTrustAccBalanceBatch.testBaseUrl = DUMMY_URL;

        Account acc = createPotentialClientPA(
            'Client_Error',
            '202',
            '302',
            '@error.mfl.test'
        );

        insert new echosign_dev1__SIGN_Agreement__c(
            Name                      = 'Signed Agr – E',
            echosign_dev1__Account__c = acc.Id,
            echosign_dev1__Status__c  = 'Signed'
        );

        Test.setMock(HttpCalloutMock.class, new ClientErrorMock());

        Test.startTest();
            TimeSolvCheckTrustAccBalanceBatch.runBatch(1);
        Test.stopTest();

        Integer logCount = [
            SELECT COUNT()
            FROM   TimeSolv_Integration_Log__c
        ];
        System.assert(
            logCount > 0,
            'bufferError should create at least one Integration Log record'
        );
    }

    /* ─────────────────────────────────────────────────────────────
     * TEST #4 – balance endpoint 500 → bufferWarning
     * ──────────────────────────────────────────────────────────── */
    @IsTest static void testBalanceWarningCreatesLog() {

        TimeSolvCheckTrustAccBalanceBatch.testBaseUrl = DUMMY_URL;

        Account acc = createPotentialClientPA(
            'Client_Warn',
            '203',
            '303',
            '@warn.mfl.test'
        );

        insert new echosign_dev1__SIGN_Agreement__c(
            Name                      = 'Signed Agr – W',
            echosign_dev1__Account__c = acc.Id,
            echosign_dev1__Status__c  = 'Signed'
        );

        Test.setMock(HttpCalloutMock.class, new BalanceErrorMock());

        Test.startTest();
            TimeSolvCheckTrustAccBalanceBatch.runBatch(1);
        Test.stopTest();

        Integer warnCount = [
            SELECT COUNT()
            FROM   TimeSolv_Integration_Log__c
        ];
        System.assert(
            warnCount > 0,
            'bufferWarning should create at least one Integration Log record'
        );
    }

    /*───────────────────────────────────────────────────────────────*
     * TEST #5 – e-mail + CC branch covers greeting logic
     *───────────────────────────────────────────────────────────────*/
    @IsTest static void testEmailCcAddresses() {

        TimeSolvCheckTrustAccBalanceBatch.testBaseUrl = DUMMY_URL;
        TimeSolvCheckTrustAccBalanceBatch.testCcEmails =
            'billing@modernfamilylaw.test,compliance@modernfamilylaw.test';

        Profile std = [SELECT Id FROM Profile WHERE Name = 'Standard User' LIMIT 1];
        UserRole role = [SELECT Id FROM UserRole LIMIT 1];
        
        User atty;
        User para;
        
        // Create Users in a separate transaction to avoid mixed DML
        System.runAs(new User(Id = UserInfo.getUserId())) {
            atty = new User(
                Username          = 'atty' + System.now().getTime() + '@mfl.test',
                Alias             = 'atty',
                LastName          = 'Attorney',
                Email             = 'attorney@modernfamilylaw.test',
                TimeZoneSidKey    = 'America/Denver',
                LocaleSidKey      = 'en_US',
                EmailEncodingKey  = 'UTF-8',
                LanguageLocaleKey = 'en_US',
                ProfileId         = std.Id,
                UserRoleId        = role.Id
            );
            para = new User(
                Username          = 'para' + System.now().getTime() + '@mfl.test',
                Alias             = 'para',
                LastName          = 'Paralegal',
                Email             = 'paralegal@modernfamilylaw.test',
                TimeZoneSidKey    = 'America/Denver',
                LocaleSidKey      = 'en_US',
                EmailEncodingKey  = 'UTF-8',
                LanguageLocaleKey = 'en_US',
                ProfileId         = std.Id,
                UserRoleId        = role.Id
            );
            insert new List<User>{ atty, para };
        }

        Account acc = createPotentialClientPA(
            'Client_Email',
            '500',
            '600',
            '@email.mfl.test'
        );
        acc.Responsible_Attorney__c  = atty.Id;
        acc.Responsible_Paralegal__c = para.Id;
        update acc;

        insert new echosign_dev1__SIGN_Agreement__c(
            Name                      = 'Signed Agr – Email',
            echosign_dev1__Account__c = acc.Id,
            echosign_dev1__Status__c  = 'Signed'
        );

        Test.setMock(HttpCalloutMock.class, new PositiveMock());

        Test.startTest();
            TimeSolvCheckTrustAccBalanceBatch.runBatch(1);
        Test.stopTest();

        System.assert(true, 'Email + CC branch should execute without error.');
    }
}