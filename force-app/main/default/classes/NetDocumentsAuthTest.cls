@isTest
public class NetDocumentsAuthTest {

    @isTest
    static void testObtainAccessTokenSuccess() {
        Test.setMock(HttpCalloutMock.class, new MockHttpCalloutSuccess());

        NetDocumentsSettings__c settings = new NetDocumentsSettings__c(
            Refresh_Token__c = 'mockStoredRefreshToken'
        );
        upsert settings;

        Test.startTest();
        String accessToken = NetDocumentsAuth.obtainAccessTokenUsingStoredRefreshToken();
        Test.stopTest();

        System.assertNotEquals(null, accessToken, 'Access token should not be null');
        System.assertEquals('mockAccessToken', accessToken, 'Access token should match the mock response');
    }

    @isTest
    static void testObtainAccessTokenFailure() {
        Test.setMock(HttpCalloutMock.class, new MockHttpCalloutFailure());

        NetDocumentsSettings__c settings = new NetDocumentsSettings__c(
            Refresh_Token__c = 'mockStoredRefreshToken'
        );
        upsert settings;

        Test.startTest();
        String accessToken = NetDocumentsAuth.obtainAccessTokenUsingStoredRefreshToken();
        Test.stopTest();

        System.assertEquals(null, accessToken, 'Access token should be null for a failed request');
    }

    private class MockHttpCalloutSuccess implements HttpCalloutMock {
        public HttpResponse respond(HttpRequest req) {
            HttpResponse res = new HttpResponse();
            res.setStatusCode(200);
            res.setHeader('Content-Type', 'application/json');
            res.setBody('{"access_token": "mockAccessToken", "refresh_token": "mockRefreshToken"}');
            return res;
        }
    }

    private class MockHttpCalloutFailure implements HttpCalloutMock {
        public HttpResponse respond(HttpRequest req) {
            HttpResponse res = new HttpResponse();
            res.setStatusCode(400);
            res.setHeader('Content-Type', 'application/json');
            res.setBody('{"error": "invalid_grant"}');
            return res;
        }
    }
}