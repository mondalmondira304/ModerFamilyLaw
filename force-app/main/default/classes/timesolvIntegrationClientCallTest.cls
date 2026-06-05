@IsTest
private class timesolvIntegrationClientCallTest {
    //───────────────────────────────────────────────────────────────────────────
    // Mocks for various HTTP callout scenarios
    //───────────────────────────────────────────────────────────────────────────
    private class MockHttpGood implements HttpCalloutMock {
        public HTTPResponse respond(HTTPRequest req) {
            HttpResponse res = new HttpResponse();
            String u = req.getEndpoint().toLowerCase();
            String m = req.getMethod();
            if (u.contains('/oauth') || u.contains('token')) {
                res.setStatusCode(200);
                res.setHeader('Content-Type','application/json');
                res.setBody('{"access_token":"fake","token_type":"bearer","expires_in":3600}');
            } else if (m=='POST' && u.endsWith('/client')) {
                res.setStatusCode(201);
                res.setHeader('Content-Type','application/json');
                res.setBody('{"Status":{"ResponseCode":201},"Details":[{"Id":321}]}');
            } else if (m=='GET' && u.contains('/client?clientid=')) {
                res.setStatusCode(200);
                res.setHeader('Content-Type','application/json');
                res.setBody('{"Status":{"ResponseCode":200},"Client":{"Id":321,"ClientId":"NUM-987"}}');
            } else if (m=='PUT' && u.endsWith('/client')) {
                res.setStatusCode(200);
            } else if (m=='POST' && u.contains('/project')) {
                res.setStatusCode(201);
                res.setHeader('Content-Type','application/json');
                res.setBody('{"Details":[{"Id":5555}]}');
            } else {
                res.setStatusCode(404);
            }
            return res;
        }
    }
    private class MockHttpBlankToken implements HttpCalloutMock {
        public HTTPResponse respond(HTTPRequest req) {
            HttpResponse res = new HttpResponse();
            String u = req.getEndpoint().toLowerCase();
            if (u.contains('/oauth') || u.contains('token')) {
                res.setStatusCode(200);
                res.setBody('{"access_token":"","token_type":"bearer","expires_in":3600}');
            } else {
                res.setStatusCode(500);
            }
            return res;
        }
    }
    private class MockHttpErrorOnCreate implements HttpCalloutMock {
        public HTTPResponse respond(HTTPRequest req) {
            HttpResponse res = new HttpResponse();
            String u = req.getEndpoint().toLowerCase();
            String m = req.getMethod();
            if (u.contains('/oauth') || u.contains('token')) {
                res.setStatusCode(200);
                res.setBody('{"access_token":"fake","token_type":"bearer","expires_in":3600}');
            } else if (m=='POST' && u.endsWith('/client')) {
                res.setStatusCode(500);
                res.setBody('{"error":"server"}');
            } else {
                return new MockHttpGood().respond(req);
            }
            return res;
        }
    }
    private class MockHttpNoClientInGet implements HttpCalloutMock {
        public HTTPResponse respond(HTTPRequest req) {
            if (req.getMethod()=='GET' && req.getEndpoint().toLowerCase().contains('/client?clientid=')) {
                HttpResponse res = new HttpResponse();
                res.setStatusCode(200);
                res.setBody('{"Status":{"ResponseCode":200},"Client":null}');
                return res;
            }
            return new MockHttpGood().respond(req);
        }
    }
    private class MockHttpGetError implements HttpCalloutMock {
        public HTTPResponse respond(HTTPRequest req) {
            if (req.getMethod()=='GET' && req.getEndpoint().toLowerCase().contains('/client?clientid=')) {
                HttpResponse res = new HttpResponse();
                res.setStatusCode(500);
                res.setBody('{"error":"nope"}');
                return res;
            }
            return new MockHttpGood().respond(req);
        }
    }
    private class MockHttpPutError implements HttpCalloutMock {
        public HTTPResponse respond(HTTPRequest req) {
            String u = req.getEndpoint().toLowerCase();
            if (req.getMethod()=='PUT' && u.endsWith('/client')) {
                HttpResponse res = new HttpResponse();
                res.setStatusCode(500);
                res.setBody('{"error":"bad put"}');
                return res;
            }
            return new MockHttpGood().respond(req);
        }
    }

    //───────────────────────────────────────────────────────────────────────────
    // Shared setup: one Attorney + one “good” Account
    //───────────────────────────────────────────────────────────────────────────
    @TestSetup
    static void setupData() {
        Profile p = [SELECT Id FROM Profile WHERE Name='Standard User' LIMIT 1];
        User u = new User(
            Username         = 'resp' + Math.abs(Crypto.getRandomInteger()) + '@test.com',
            Email            = 'resp@test.com',
            LastName         = 'Attorney',
            FirstName        = 'Resp',
            Alias            = 'rtest',
            TimeZoneSidKey   = 'America/Chicago',
            LocaleSidKey     = 'en_US',
            EmailEncodingKey = 'UTF-8',
            LanguageLocaleKey= 'en_US',
            ProfileId        = p.Id,
            MFL_Office__c    = 'Denver'
        );
        insert u;
        insert new Account(
            Name                    = 'HasClient',
            TimeSolv_Client_Id__c   = 'C-999',
            Responsible_Attorney__c = u.Id
        );
    }

    //───────────────────────────────────────────────────────────────────────────
    // 1) Happy path
    //───────────────────────────────────────────────────────────────────────────
    static testMethod void testHappyPath() {
        timesolvIntegrationMatterCall.skipChainedContactCall = true;
        Test.setMock(HttpCalloutMock.class, new MockHttpGood());

        Account acct = [
            SELECT Id, Responsible_Attorney__c
              FROM Account
             WHERE TimeSolv_Client_Id__c='C-999'
             LIMIT 1
        ];
        Test.startTest();
            System.enqueueJob(new timesolvIntegrationClientCall(
                new List<Id>{ acct.Id }
            ));
        Test.stopTest();

        Account a = [SELECT TimeSolv_Client_Id__c, Timesolv_Client_Number__c
                       FROM Account WHERE Id = :acct.Id];
        System.assertEquals('321',    a.TimeSolv_Client_Id__c);
        System.assertEquals('NUM-987', a.Timesolv_Client_Number__c);
    }

    //───────────────────────────────────────────────────────────────────────────
    // 2) Creates when initial ID blank
    //───────────────────────────────────────────────────────────────────────────
    static testMethod void testCreatesWhenNoClientId() {
        timesolvIntegrationMatterCall.skipChainedContactCall = true;
        Test.setMock(HttpCalloutMock.class, new MockHttpGood());

        Id attorneyId = [SELECT Responsible_Attorney__c
                            FROM Account
                           WHERE TimeSolv_Client_Id__c='C-999'
                           LIMIT 1].Responsible_Attorney__c;

        Account noClient = new Account(
            Name                    = 'NoClient',
            Responsible_Attorney__c = attorneyId
        );
        insert noClient;

        Test.startTest();
            System.enqueueJob(new timesolvIntegrationClientCall(
                new List<Id>{ noClient.Id }
            ));
        Test.stopTest();

        noClient = [SELECT TimeSolv_Client_Id__c, Timesolv_Client_Number__c
                      FROM Account WHERE Id = :noClient.Id];
        System.assertEquals('321',    noClient.TimeSolv_Client_Id__c);
        System.assertEquals('NUM-987', noClient.Timesolv_Client_Number__c);
    }

    //───────────────────────────────────────────────────────────────────────────
    // 3) Blank token → early exit + error log
    //───────────────────────────────────────────────────────────────────────────
    static testMethod void testBlankToken() {
        timesolvIntegrationMatterCall.skipChainedContactCall = true;
        Test.setMock(HttpCalloutMock.class, new MockHttpBlankToken());

        Account acct = [
            SELECT Id
              FROM Account
             WHERE TimeSolv_Client_Id__c='C-999'
             LIMIT 1
        ];
        Test.startTest();
            System.enqueueJob(new timesolvIntegrationClientCall(
                new List<Id>{ acct.Id }
            ));
        Test.stopTest();

        TimeSolvIntegrationLogUtil.savePendingLogs();
        Integer countLogs = [
            SELECT count()
              FROM TimeSolv_Integration_Log__c
             WHERE Integration_Type__c = :TimeSolvIntegrationLogUtil.INTEGRATION_TYPE_CLIENT
               AND Type__c             = :TimeSolvIntegrationLogUtil.LOG_TYPE_ERROR
        ];
        System.assertEquals(1, countLogs);
    }

    //───────────────────────────────────────────────────────────────────────────
    // 4) Create-client error → error log + task
    //───────────────────────────────────────────────────────────────────────────
    static testMethod void testCreateClientError() {
        timesolvIntegrationMatterCall.skipChainedContactCall = true;
        Test.setMock(HttpCalloutMock.class, new MockHttpErrorOnCreate());

        Account acct = [
            SELECT Id
              FROM Account
             WHERE TimeSolv_Client_Id__c='C-999'
             LIMIT 1
        ];
        Test.startTest();
            System.enqueueJob(new timesolvIntegrationClientCall(
                new List<Id>{ acct.Id }
            ));
        Test.stopTest();

        TimeSolvIntegrationLogUtil.savePendingLogs();
        Integer countLogs = [
            SELECT count()
              FROM TimeSolv_Integration_Log__c
             WHERE Integration_Type__c = :TimeSolvIntegrationLogUtil.INTEGRATION_TYPE_CLIENT
               AND Type__c             = :TimeSolvIntegrationLogUtil.LOG_TYPE_ERROR
        ];
        System.assertEquals(1, countLogs);

        Integer countTasks = [
            SELECT count()
              FROM Task
             WHERE Subject LIKE 'TimeSolv Error: Client Creation%'
        ];
        System.assertEquals(1, countTasks);
    }

    //───────────────────────────────────────────────────────────────────────────
    // 5) GET yields no client → warning log
    //───────────────────────────────────────────────────────────────────────────
    static testMethod void testGetNoClientNumber() {
        Test.setMock(HttpCalloutMock.class, new MockHttpNoClientInGet());

        // now SELECT TimeSolv_Client_Id__c so getTSClientId param is present
        Account acct = [
            SELECT Id, TimeSolv_Client_Id__c
              FROM Account
             WHERE TimeSolv_Client_Id__c='C-999'
             LIMIT 1
        ];
        Test.startTest();
            timesolvIntegrationClientCall.getTSClientId(
                acct.TimeSolv_Client_Id__c, 'fake', acct
            );
        Test.stopTest();

        TimeSolvIntegrationLogUtil.savePendingLogs();
        Integer countWarns = [
            SELECT count()
              FROM TimeSolv_Integration_Log__c
             WHERE Integration_Type__c = :TimeSolvIntegrationLogUtil.INTEGRATION_TYPE_CLIENT
               AND Type__c             = :TimeSolvIntegrationLogUtil.LOG_TYPE_WARNING
        ];
        System.assertEquals(1, countWarns);
    }

    //───────────────────────────────────────────────────────────────────────────
    // 6) GET error → error log
    //───────────────────────────────────────────────────────────────────────────
    static testMethod void testGetErrorResponse() {
        Test.setMock(HttpCalloutMock.class, new MockHttpGetError());

        // now SELECT TimeSolv_Client_Id__c so getTSClientId param is present
        Account acct = [
            SELECT Id, TimeSolv_Client_Id__c
              FROM Account
             WHERE TimeSolv_Client_Id__c='C-999'
             LIMIT 1
        ];
        Test.startTest();
            timesolvIntegrationClientCall.getTSClientId(
                acct.TimeSolv_Client_Id__c, 'fake', acct
            );
        Test.stopTest();

        TimeSolvIntegrationLogUtil.savePendingLogs();
        Integer countErrors = [
            SELECT count()
              FROM TimeSolv_Integration_Log__c
             WHERE Integration_Type__c = :TimeSolvIntegrationLogUtil.INTEGRATION_TYPE_CLIENT
               AND Type__c             = :TimeSolvIntegrationLogUtil.LOG_TYPE_ERROR
        ];
        System.assertEquals(1, countErrors);
    }

    //───────────────────────────────────────────────────────────────────────────
    // 7) PUT error → error log
    //───────────────────────────────────────────────────────────────────────────
    static testMethod void testPutError() {
        Test.setMock(HttpCalloutMock.class, new MockHttpPutError());

        Account acct = new Account(
            Name                      = 'X',
            TimeSolv_Client_Id__c     = '999',
            Timesolv_Client_Number__c = 'NNN'
        );
        insert acct;

        Test.startTest();
            timesolvIntegrationClientCall.updateClientAPIForClientNumber(
                acct, '999', 'NNN', 'fake'
            );
        Test.stopTest();

        TimeSolvIntegrationLogUtil.savePendingLogs();
        Integer countErrors = [
            SELECT count()
              FROM TimeSolv_Integration_Log__c
             WHERE Integration_Type__c = :TimeSolvIntegrationLogUtil.INTEGRATION_TYPE_CLIENT
               AND Type__c             = :TimeSolvIntegrationLogUtil.LOG_TYPE_ERROR
        ];
        System.assertEquals(1, countErrors);
    }
}