@IsTest
private class timesolvIntegrationTokenUtilTest {
    private class SuccessMock implements HttpCalloutMock {
        public HTTPResponse respond(HTTPRequest req) {
            HttpResponse res = new HttpResponse();
            res.setStatusCode(200);
            res.setBody('{"access_token":"MOCK123","token_type":"bearer","expires_in":1200}');
            return res;
        }
    }
    private class FailMock implements HttpCalloutMock {
        public HTTPResponse respond(HTTPRequest req) {
            HttpResponse res = new HttpResponse();
            res.setStatusCode(500);
            return res;
        }
    }

    static testMethod void testTestModeShortCircuit() {
        String token = timesolvIntegrationTokenUtil.getBearerToken();
        System.assertEquals('TEST_TOKEN', token);
    }

    static testMethod void testMissingBaseUrlThrows() {
        timesolvIntegrationTokenUtil.skipTestCheck = true;
        timesolvIntegrationTokenUtil.baseUrlStatic = '';
        timesolvIntegrationTokenUtil.configStatic = new TimeSolv_Integration_Configuration__mdt(
            DeveloperName   = 'Prod', 
            Client_ID__c    = 'X', 
            Client_Secret__c= 'Y',
            Auth_Code__c    = 'Z',
            Redirect_URI__c = 'https://x'
        );

        try {
            timesolvIntegrationTokenUtil.getBearerToken();
            System.assert(false, 'Expected TokenRetrievalException for missing baseUrl');
        } catch (Exception e) {
            System.assert(
                e instanceof timesolvIntegrationTokenUtil.TokenRetrievalException &&
                e.getMessage().contains('URL not configured'),
                'Wrong exception for missing URL: ' + e
            );
        }
    }

    static testMethod void testMissingConfigThrows() {
        timesolvIntegrationTokenUtil.skipTestCheck = true;
        timesolvIntegrationTokenUtil.baseUrlStatic = 'https://dummy';
        timesolvIntegrationTokenUtil.configStatic  = null;

        try {
            timesolvIntegrationTokenUtil.getBearerToken();
            System.assert(false, 'Expected TokenRetrievalException for missing config');
        } catch (Exception e) {
            System.assert(
                e instanceof timesolvIntegrationTokenUtil.TokenRetrievalException &&
                e.getMessage().contains('configuration not found'),
                'Wrong exception for missing config: ' + e
            );
        }
    }

    static testMethod void testHttpSuccessPath() {
        timesolvIntegrationTokenUtil.skipTestCheck = true;
        timesolvIntegrationTokenUtil.baseUrlStatic = 'https://dummy';
        timesolvIntegrationTokenUtil.configStatic = new TimeSolv_Integration_Configuration__mdt(
            DeveloperName   = 'Prod', 
            Client_ID__c    = 'A', 
            Client_Secret__c= 'B',
            Auth_Code__c    = 'C',
            Redirect_URI__c = 'https://x'
        );

        Test.setMock(HttpCalloutMock.class, new SuccessMock());
        Test.startTest();
        String result = timesolvIntegrationTokenUtil.getBearerToken();
        Test.stopTest();

        System.assertEquals('MOCK123', result, 'Should return the mock token');
    }

    static testMethod void testHttpFailureRetriesThenThrows() {
        timesolvIntegrationTokenUtil.skipTestCheck = true;
        timesolvIntegrationTokenUtil.baseUrlStatic = 'https://dummy';
        timesolvIntegrationTokenUtil.configStatic = new TimeSolv_Integration_Configuration__mdt(
            DeveloperName   = 'Prod', 
            Client_ID__c    = 'A', 
            Client_Secret__c= 'B',
            Auth_Code__c    = 'C',
            Redirect_URI__c = 'https://x'
        );

        Test.setMock(HttpCalloutMock.class, new FailMock());
        Test.startTest();
        try {
            timesolvIntegrationTokenUtil.getBearerToken();
            System.assert(false, 'Expected exception after retries exhausted');
        } catch (Exception e) {
            System.assert(
                e instanceof timesolvIntegrationTokenUtil.TokenRetrievalException &&
                e.getMessage().contains('Unable to retrieve'),
                'Wrong exception on HTTP failures: ' + e
            );
        }
        Test.stopTest();
    }
}