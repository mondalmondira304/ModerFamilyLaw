@IsTest
public class CallQueueableTest {

    @TestSetup
    static void setupCustomSettings() {
        // Setup initial custom settings for the refresh token
        ZccCredentials__c zoomCred = new ZccCredentials__c();
        zoomCred.Refresh_Token_Part1__c = 'dummyRefreshTokenPart1';
        zoomCred.Refresh_Token_Part2__c = 'dummyRefreshTokenPart2';
        zoomCred.Refresh_Token_Part3__c = 'dummyRefreshTokenPart3';
        insert zoomCred;
    }

    @IsTest
    static void testDailyCallTypeWithValidToken() {
        // Mock the HTTP response to return a valid token and simulate the daily callout
        Test.setMock(HttpCalloutMock.class, new MockHttpResponseGenerator(true));

        // Test the Queueable with 'daily' call type
        CallQueueable queueable = new CallQueueable('daily');
        Test.startTest();
        System.enqueueJob(queueable);
        Test.stopTest();
    }

    @IsTest
    static void testMonthlyCallTypeWithValidToken() {
        // Mock the HTTP response to return a valid token and simulate the monthly callout
        Test.setMock(HttpCalloutMock.class, new MockHttpResponseGenerator(true));

        // Test the Queueable with 'monthly' call type
        CallQueueable queueable = new CallQueueable('monthly');
        Test.startTest();
        System.enqueueJob(queueable);
        Test.stopTest();
    }

    // NEW: Test the 'detail' call type with a valid token
    @IsTest
    static void testDetailCallTypeWithValidToken() {
        // Mock the HTTP response to return a valid token and simulate the detail callout
        Test.setMock(HttpCalloutMock.class, new MockHttpResponseGenerator(true));

        // Test the Queueable with 'detail' call type
        CallQueueable queueable = new CallQueueable('detail');
        Test.startTest();
        System.enqueueJob(queueable);
        Test.stopTest();
    }

    @IsTest
    static void testInvalidCallTypeWithValidToken() {
        // Mock the HTTP response to return a valid token
        Test.setMock(HttpCalloutMock.class, new MockHttpResponseGenerator(true));

        // Test the Queueable with an invalid call type
        CallQueueable queueable = new CallQueueable('invalidType');
        Test.startTest();
        System.enqueueJob(queueable);
        Test.stopTest();
    }

    @IsTest
    static void testDailyCallTypeWithNullToken() {
        // Mock the HTTP response to simulate a null access token
        Test.setMock(HttpCalloutMock.class, new MockHttpResponseGenerator(false)); // false => no access token

        // Test the Queueable with 'daily' type but without a valid access token
        CallQueueable queueable = new CallQueueable('daily');
        Test.startTest();
        System.enqueueJob(queueable);
        Test.stopTest();
    }

    // NEW: Test the 'detail' call type with a failed token refresh
    @IsTest
    static void testDetailCallTypeWithNullToken() {
        // Mock the HTTP response to simulate a null/invalid access token
        Test.setMock(HttpCalloutMock.class, new MockHttpResponseGenerator(false));

        // Test the Queueable with 'detail' call type but no valid token
        CallQueueable queueable = new CallQueueable('detail');
        Test.startTest();
        System.enqueueJob(queueable);
        Test.stopTest();
    }

    @IsTest
    static void testZoomTokenUtilitySuccess() {
        // Test the refreshAccessToken method for successful token retrieval
        Test.setMock(HttpCalloutMock.class, new MockHttpResponseGenerator(true));

        Test.startTest();
        String token = ZoomTokenUtility.refreshAccessToken();
        Test.stopTest();

        System.assertNotEquals(null, token, 'Expected a valid token to be returned.');
    }

    @IsTest
    static void testZoomTokenUtilityFailure() {
        // Test the refreshAccessToken method with a simulated failed callout (non-200 response)
        Test.setMock(HttpCalloutMock.class, new MockHttpResponseGenerator(false));

        Test.startTest();
        String token = ZoomTokenUtility.refreshAccessToken();
        Test.stopTest();

        System.assertEquals(null, token, 'Expected null to be returned for a failed token refresh.');
    }

    // Mock class for HttpCalloutMock to simulate different responses
    private class MockHttpResponseGenerator implements HttpCalloutMock {
        private Boolean validToken;

        // Constructor to set whether we return a valid token
        MockHttpResponseGenerator(Boolean validToken) {
            this.validToken = validToken;
        }

        public HTTPResponse respond(HTTPRequest req) {
            HttpResponse res = new HttpResponse();
            res.setHeader('Content-Type', 'application/json');
            
            // 1) Simulate token response
            if (req.getEndpoint().contains('token')) {
                if (validToken) {
                    res.setBody('{"access_token": "mockAccessToken", "refresh_token": "newRefreshToken"}');
                    res.setStatusCode(200);
                } else {
                    res.setBody('{"error": "invalid_grant"}');
                    res.setStatusCode(401); // Unauthorized or failed token
                }
            }
            // 2) Simulate daily/monthly/detail callout
            else if (req.getEndpoint().contains('daily') 
                  || req.getEndpoint().contains('monthly') 
                  || req.getEndpoint().contains('detail')) 
            {
                // Return success JSON for simplicity
                res.setBody('{"status": "success"}');
                res.setStatusCode(200);
            }
            // 3) Fallback
            else {
                res.setBody('{"message": "Unknown endpoint"}');
                res.setStatusCode(404);
            }
            return res;
        }
    }
}