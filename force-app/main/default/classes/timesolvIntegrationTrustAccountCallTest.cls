@IsTest(SeeAllData=false)
private class timesolvIntegrationTrustAccountCallTest {
    //── Mocks ────────────────────────────────────────────────────────────
    private class MockSuccess implements HttpCalloutMock {
        public HTTPResponse respond(HTTPRequest req) {
            HttpResponse res = new HttpResponse();
            res.setStatusCode(200);
            res.setHeader('Content-Type','application/json');
            // match your TrustAccountApiResponse format
            res.setBody('{"Details":[{"Id":999}]}');
            return res;
        }
    }
    private class MockError implements HttpCalloutMock {
        public HTTPResponse respond(HTTPRequest req) {
            HttpResponse res = new HttpResponse();
            res.setStatusCode(500);
            res.setHeader('Content-Type','application/json');
            res.setBody('{"Message":"Server error"}');
            return res;
        }
    }

    @TestSetup
    static void setupMdAndData() {
        // 1) Create a user to act as Responsible_Attorney__c
        Profile p = [SELECT Id FROM Profile WHERE Name='System Administrator' LIMIT 1];
        String suffix = String.valueOf(Math.mod(System.currentTimeMillis(), 10)); 

        User u = new User(
            Username           = 'attorney'+Math.random()+'@example.com',
            LastName           = 'Attorney',
            Email              = 'a@test.com',
            Alias              = 'tattny'+suffix,
            TimeZoneSidKey     = 'America/Chicago',
            LocaleSidKey       = 'en_US',
            EmailEncodingKey   = 'UTF-8',
            LanguageLocaleKey  = 'en_US',
            ProfileId          = p.Id,
            MFL_Office__c      = 'Denver'
        );
        insert u;

        // 2) Two Accounts: one with attorney, one without
        insert new Account(
            Name                   = 'WithAttorney',
            TimeSolv_Matter_Id__c  = '100',
            Quoted_Retainer__c     = 123,
            Responsible_Attorney__c= u.Id
        );
        insert new Account(
            Name                  = 'NoAttorney',
            TimeSolv_Matter_Id__c = '200',
            Quoted_Retainer__c    = 456
            // no Responsible_Attorney__c
        );

        // 3) (Optional) If you want to test matching an office to a bankId,
        //    you can insert a custom metadata record here. But it's not required
        //    to bump +10% coverage since we cover both the rawOffice-null and
        //    rawOffice-present branches.
    }

    @IsTest static void success_withAttorney_andExplicitAcctId() {
        Account acct = [SELECT Id, TimeSolv_Matter_Id__c FROM Account WHERE Name='WithAttorney'];
        Test.setMock(HttpCalloutMock.class, new MockSuccess());
        Test.startTest();
            // call execute() directly so we don’t enqueue another job
            new timesolvIntegrationTrustAccountCall(
                acct.TimeSolv_Matter_Id__c,
                'dummyToken',
                acct.Id
            ).execute(null);
        Test.stopTest();

        acct = [SELECT Timesolv_trustAccount_Id__c FROM Account WHERE Id=:acct.Id];
        System.assertEquals('999', acct.Timesolv_trustAccount_Id__c,
            'Expected trustAccountId from mock success');
    }

    @IsTest static void success_noAttorney_andNoAcctId() {
        Account acct = [SELECT Id, TimeSolv_Matter_Id__c FROM Account WHERE Name='NoAttorney'];
        Test.setMock(HttpCalloutMock.class, new MockSuccess());
        Test.startTest();
            // use the overload without passing accountId
            new timesolvIntegrationTrustAccountCall(
                acct.TimeSolv_Matter_Id__c,
                'dummyToken'
            ).execute(null);
        Test.stopTest();

        acct = [SELECT Timesolv_trustAccount_Id__c FROM Account WHERE Id=:acct.Id];
        System.assertEquals('999', acct.Timesolv_trustAccount_Id__c,
            'Should still set trustAccountId even when no Responsible Attorney was provided');
    }

    @IsTest static void errorPath_leavesFieldBlank() {
        Account acct = [SELECT Id, TimeSolv_Matter_Id__c FROM Account WHERE Name='WithAttorney'];
        Test.setMock(HttpCalloutMock.class, new MockError());
        Test.startTest();
            new timesolvIntegrationTrustAccountCall(
                acct.TimeSolv_Matter_Id__c,
                'dummyToken',
                acct.Id
            ).execute(null);
        Test.stopTest();

        acct = [SELECT Timesolv_trustAccount_Id__c FROM Account WHERE Id=:acct.Id];
        System.assertEquals(
           null,
          acct.Timesolv_trustAccount_Id__c,
          'On HTTP 500, we should not populate the trustAccountId'
       );
    }
}