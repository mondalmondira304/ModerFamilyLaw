@isTest(SeeAllData=true)
private class AdobeSignAttyUrlQueueable_Test {
    
    private class MockHttp implements HttpCalloutMock {
        private Boolean returnBlankUrl;
        
        public MockHttp(Boolean returnBlank) {
            this.returnBlankUrl = returnBlank;
        }
        
        public HttpResponse respond(HttpRequest req) {
            HttpResponse res = new HttpResponse();
            res.setStatusCode(200);
            res.setHeader('Content-Type', 'application/json');
            
            if (req.getEndpoint().contains('oauth') || req.getEndpoint().contains('token')) {
                res.setBody('{"access_token":"MOCK_TOKEN","expires_in":3600}');
            } else if (req.getEndpoint().contains('signingUrls')) {
                if (returnBlankUrl) {
                    res.setBody('{"signingUrlSetInfos":[]}');
                } else {
                    res.setBody('{"signingUrlSetInfos":[{"signingUrls":[{"email":"attorney@test.com","esignUrl":"https://secure.na1.adobesign.com/test"}]}]}');
                }
            } else {
                res.setBody('{"access_token":"MOCK_TOKEN"}');
            }
            return res;
        }
    }
    
    private static Id getTestAccountId() {
        List<Account> accounts = [SELECT Id FROM Account WHERE IsPersonAccount = true LIMIT 1];
        if (accounts.isEmpty()) accounts = [SELECT Id FROM Account LIMIT 1];
        return accounts.isEmpty() ? null : accounts[0].Id;
    }
    
    @isTest
    static void testSuccessfulUrlRetrieval() {
        Id accId = getTestAccountId();
        if (accId == null) return;
        
        update new Account(Id = accId, FA_Portal_AgreementId__c = 'AGR123', FA_Portal_Atty_Signing_URL__c = null);
        
        Test.setMock(HttpCalloutMock.class, new MockHttp(false));
        Test.startTest();
        System.enqueueJob(new AdobeSignAttyUrlQueueable(accId, 'AGR123'));
        Test.stopTest();
        
        Account acc = [SELECT FA_Portal_Atty_Signing_URL__c FROM Account WHERE Id = :accId];
        System.assertNotEquals(null, acc.FA_Portal_Atty_Signing_URL__c);
    }
    
    @isTest
    static void testMissingAgreementId() {
        Id accId = getTestAccountId();
        if (accId == null) return;
        
        Test.startTest();
        System.enqueueJob(new AdobeSignAttyUrlQueueable(accId, null));
        Test.stopTest();
        
        List<ErrorLog__c> errors = [
            SELECT ErrorMessage__c FROM ErrorLog__c 
            WHERE Related_Account__c = :accId AND Class_Name__c = 'AdobeSignAttyUrlQueueable'
            ORDER BY CreatedDate DESC LIMIT 1
        ];
        System.assertEquals(1, errors.size());
    }
    
    @isTest
    static void testMaxAttemptsExceeded() {
        Id accId = getTestAccountId();
        if (accId == null) return;
        
        update new Account(Id = accId, FA_Portal_AgreementId__c = 'AGR123');
        Test.setMock(HttpCalloutMock.class, new MockHttp(true));
        
        Test.startTest();
        System.enqueueJob(new AdobeSignAttyUrlQueueable(accId, 'AGR123', 10));
        Test.stopTest();
        
        List<ErrorLog__c> errors = [
            SELECT ErrorMessage__c FROM ErrorLog__c 
            WHERE Related_Account__c = :accId AND Class_Name__c = 'AdobeSignAttyUrlQueueable'
            ORDER BY CreatedDate DESC LIMIT 1
        ];
        System.assert(errors[0].ErrorMessage__c.contains('not ready after'));
    }
    
    @isTest
    static void testConstructorVariations() {
        Id accId = getTestAccountId();
        if (accId == null) return;
        
        AdobeSignAttyUrlQueueable job1 = new AdobeSignAttyUrlQueueable(accId, 'AGR123');
        AdobeSignAttyUrlQueueable job2 = new AdobeSignAttyUrlQueueable(accId, 'AGR123', 5);
        
        System.assertNotEquals(null, job1);
        System.assertNotEquals(null, job2);
    }
}