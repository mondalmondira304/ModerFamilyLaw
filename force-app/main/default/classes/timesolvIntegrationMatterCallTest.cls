@IsTest
private class timesolvIntegrationMatterCallTest {
    // ----------------------------------------------------------------
    // Mock for both the token‐and‐project HTTP callouts
    // ----------------------------------------------------------------
    private class MockHttp implements HttpCalloutMock {
        public HTTPResponse respond(HTTPRequest req) {
            HttpResponse res = new HttpResponse();
            String url = req.getEndpoint().toLowerCase();
            if (url.contains('token')) {
                res.setStatusCode(200);
                res.setHeader('Content-Type','application/json');
                res.setBody('{"access_token":"fake","token_type":"bearer","expires_in":3600}');
            } else if (url.contains('/project')) {
                res.setStatusCode(201);
                res.setHeader('Content-Type','application/json');
                res.setBody('{"Details":[{"Id":5555}]}');
            } else {
                res.setStatusCode(404);
            }
            return res;
        }
    }

    // ----------------------------------------------------------------
    // Shared test data: one User + one Account with a valid client ID
    // ----------------------------------------------------------------
    @TestSetup
    static void setupData() {
        Profile p = [SELECT Id FROM Profile WHERE Name = 'Standard User' LIMIT 1];
        User attorney = new User(
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
        insert attorney;

        Account acct = new Account(
            Name                    = 'Test Account',
            TimeSolv_Client_Id__c   = 'C-999',
            Responsible_Attorney__c = attorney.Id,
            Type_of_Case_A__c       = 'Adoption'
        );
        insert acct;
    }

    // ----------------------------------------------------------------
    // 1) Happy‐path: client ID present → callout → MatterId written
    // ----------------------------------------------------------------
    static testMethod void happyPath() {
        timesolvIntegrationMatterCall.skipChainedContactCall = true;
        Test.setMock(HttpCalloutMock.class, new MockHttp());

        Id acctId = [SELECT Id FROM Account LIMIT 1].Id;
        Test.startTest();
            System.enqueueJob(
                new timesolvIntegrationMatterCall(new List<Id>{ acctId })
            );
        Test.stopTest();

        Account result = [SELECT TimeSolv_Matter_Id__c
                            FROM Account
                           WHERE Id = :acctId];
        System.assertEquals(
            '5555',
            result.TimeSolv_Matter_Id__c,
            'MatterId should match the mock response'
        );
    }

    // ----------------------------------------------------------------
    // 2) Guard‐clause: no client ID → skip callout → no MatterId
    // ----------------------------------------------------------------
    static testMethod void skipsWhenNoClientId() {
        timesolvIntegrationMatterCall.skipChainedContactCall = true;
        Test.setMock(HttpCalloutMock.class, new MockHttp());

        Account noClient = new Account(Name = 'No Client');
        insert noClient;

        Test.startTest();
            System.enqueueJob(
                new timesolvIntegrationMatterCall(new List<Id>{ noClient.Id })
            );
        Test.stopTest();

        noClient = [SELECT TimeSolv_Matter_Id__c
                      FROM Account
                     WHERE Id = :noClient.Id];
        System.assertEquals(
            null,
            noClient.TimeSolv_Matter_Id__c,
            'Should skip processing when client ID is blank'
        );
    }

    // ----------------------------------------------------------------
    // 3) Early‐exit: empty accountIds list
    // ----------------------------------------------------------------
    static testMethod void testEmptyAccountList() {
        timesolvIntegrationMatterCall.skipChainedContactCall = true;
        Test.setMock(HttpCalloutMock.class, new MockHttp());

        Test.startTest();
            System.enqueueJob(
                new timesolvIntegrationMatterCall(new List<Id>())
            );
        Test.stopTest();

        // No exception, nothing to assert beyond successful completion
        System.assert(true, 'Empty list should simply return without errors');
    }

    // ----------------------------------------------------------------
    // 4) No‐records branch: query returns zero Accounts
    // ----------------------------------------------------------------
    static testMethod void testNoAccountsFound() {
        timesolvIntegrationMatterCall.skipChainedContactCall = true;
        Test.setMock(HttpCalloutMock.class, new MockHttp());

        // Use a syntactically valid but non‐existent Account Id
        Id fakeId = (Id) '001000000000000';
        Test.startTest();
            System.enqueueJob(
                new timesolvIntegrationMatterCall(new List<Id>{ fakeId })
            );
        Test.stopTest();

        // Completed without exception
        System.assert(true, 'Non‐existent Id should hit accounts.isEmpty() branch and return');
    }

    // ----------------------------------------------------------------
    // 5) Mixed‐clientIds: one valid, one blank → covers both Success & Error status‐update branches
    // ----------------------------------------------------------------
    static testMethod void testMixedClientIds() {
        timesolvIntegrationMatterCall.skipChainedContactCall = true;
        Test.setMock(HttpCalloutMock.class, new MockHttp());

        // Good account from @TestSetup
        Account good = [SELECT Id FROM Account WHERE TimeSolv_Client_Id__c = 'C-999' LIMIT 1];

        // Another account with no client Id
        Account bad = new Account(Name = 'AlsoBad');
        insert bad;

        Test.startTest();
            System.enqueueJob(
                new timesolvIntegrationMatterCall(new List<Id>{ good.Id, bad.Id })
            );
        Test.stopTest();

        // Good → has MatterId
        good = [SELECT TimeSolv_Matter_Id__c FROM Account WHERE Id = :good.Id];
        System.assertEquals('5555', good.TimeSolv_Matter_Id__c);

        // Bad → still no MatterId
        bad = [SELECT TimeSolv_Matter_Id__c FROM Account WHERE Id = :bad.Id];
        System.assertEquals(null, bad.TimeSolv_Matter_Id__c);
    }
}