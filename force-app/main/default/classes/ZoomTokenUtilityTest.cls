@IsTest
public class ZoomTokenUtilityTest {

    @TestSetup
    static void setupCustomSettings() {
        // Set up custom settings with a refresh token to simulate stored tokens
        ZccCredentials__c zoomCred = new ZccCredentials__c();
        zoomCred.Refresh_Token_Part1__c = 'dummyRefreshTokenPart1';
        zoomCred.Refresh_Token_Part2__c = 'dummyRefreshTokenPart2';
        zoomCred.Refresh_Token_Part3__c = 'dummyRefreshTokenPart3';
        insert zoomCred;
    }

    @IsTest
    static void testRefreshAccessTokenSuccess() {
        // Mock HTTP response to return a valid token
        Test.setMock(HttpCalloutMock.class, new MockHttpResponseGenerator(true));

        Test.startTest();
        String accessToken = ZoomTokenUtility.refreshAccessToken();
        Test.stopTest();

        // Verify that a valid access token is returned
        System.assertNotEquals(null, accessToken, 'Expected a valid access token to be returned');
        
        // Verify that the custom settings were updated with the new tokens
        ZccCredentials__c zoomCred = ZccCredentials__c.getInstance();
        System.assertNotEquals(null, zoomCred.Access_Token_Part1__c, 'Access Token Part 1 should be set');
        System.assertNotEquals(null, zoomCred.Refresh_Token_Part1__c, 'Refresh Token Part 1 should be set');
    }

    @IsTest
    static void testRefreshAccessTokenFailure() {
        // Mock HTTP response to simulate a failed token retrieval
        Test.setMock(HttpCalloutMock.class, new MockHttpResponseGenerator(false));

        Test.startTest();
        String accessToken = ZoomTokenUtility.refreshAccessToken();
        Test.stopTest();

        // Verify that no access token is returned
        System.assertEquals(null, accessToken, 'Expected null for a failed token refresh');
    }

    @IsTest
    static void testRefreshAccessTokenException() {
        // Mock HTTP response to throw an exception
        Test.setMock(HttpCalloutMock.class, new ExceptionThrowingMock());

        Test.startTest();
        String accessToken = ZoomTokenUtility.refreshAccessToken();
        Test.stopTest();

        // Verify that null is returned if an exception occurs
        System.assertEquals(null, accessToken, 'Expected null due to exception during token refresh');
    }

    @IsTest
    static void testUpdateZoomTokens() {
        // Test storing a large access token and refresh token to ensure proper handling
        String longAccessToken = 'A'.repeat(600);
        String longRefreshToken = 'R'.repeat(600);

        Test.startTest();
        ZoomTokenUtility.updateZoomTokens(longAccessToken, longRefreshToken);
        Test.stopTest();

        // Retrieve updated custom settings and verify the token storage
        ZccCredentials__c zoomCred = ZccCredentials__c.getInstance();
        
        // Check parts of the access token
        System.assertEquals(longAccessToken.substring(0, 255), zoomCred.Access_Token_Part1__c, 'Access Token Part 1 mismatch');
        System.assertEquals(longAccessToken.substring(255, 510), zoomCred.Access_Token_Part2__c, 'Access Token Part 2 mismatch');
        System.assertEquals(longAccessToken.substring(510), zoomCred.Access_Token_Part3__c, 'Access Token Part 3 mismatch');

        // Check parts of the refresh token
        System.assertEquals(longRefreshToken.substring(0, 255), zoomCred.Refresh_Token_Part1__c, 'Refresh Token Part 1 mismatch');
        System.assertEquals(longRefreshToken.substring(255, 510), zoomCred.Refresh_Token_Part2__c, 'Refresh Token Part 2 mismatch');
        System.assertEquals(longRefreshToken.substring(510), zoomCred.Refresh_Token_Part3__c, 'Refresh Token Part 3 mismatch');
    }

    @IsTest
    static void testGetRefreshTokenFromCustomSetting() {
        // Retrieve the refresh token using the helper method
        String refreshToken = ZoomTokenUtility.getRefreshTokenFromCustomSetting();

        // Verify the reconstructed refresh token
        System.assertEquals('dummyRefreshTokenPart1dummyRefreshTokenPart2dummyRefreshTokenPart3', refreshToken, 'The refresh token should match the stored parts');
    }

    @IsTest
    static void testGetAccessToken() {
        // Mock HTTP response to return a valid token
        Test.setMock(HttpCalloutMock.class, new MockHttpResponseGenerator(true));

        Test.startTest();
        String accessToken = ZoomTokenUtility.getAccessToken();
        Test.stopTest();

        // Verify that a valid access token is returned
        System.assertNotEquals(null, accessToken, 'Expected a valid access token to be retrieved');
    }

    // Mock HTTP response generator for successful and failed callouts
    private class MockHttpResponseGenerator implements HttpCalloutMock {
        private Boolean success;

        MockHttpResponseGenerator(Boolean success) {
            this.success = success;
        }

        public HttpResponse respond(HttpRequest req) {
            HttpResponse res = new HttpResponse();
            res.setHeader('Content-Type', 'application/json');
            if (success) {
                res.setBody('{"access_token": "mockAccessToken", "refresh_token": "newMockRefreshToken"}');
                res.setStatusCode(200);
            } else {
                res.setBody('{"error": "invalid_grant"}');
                res.setStatusCode(401);
            }
            return res;
        }
    }

    // Exception-throwing mock for testing exception handling
    private class ExceptionThrowingMock implements HttpCalloutMock {
        public HttpResponse respond(HttpRequest req) {
            throw new CalloutException('Simulated callout exception');
        }
    }
}