@isTest(SeeAllData=true)
private class AdobeSignTokenUtil_Test {
    
    private class TokenMock implements HttpCalloutMock {
        private Integer statusCode;
        private String responseBody;
        
        public TokenMock(Integer statusCode, String responseBody) {
            this.statusCode = statusCode;
            this.responseBody = responseBody;
        }
        
        public HttpResponse respond(HttpRequest req) {
            HttpResponse res = new HttpResponse();
            res.setStatusCode(statusCode);
            res.setHeader('Content-Type', 'application/json');
            res.setBody(responseBody);
            return res;
        }
    }
    
    @isTest
    static void testSuccessfulTokenRefresh() {
        // Clear cached token
        AdobeSignTokenUtil.cachedAccessToken = null;
        AdobeSignTokenUtil.tokenExpiry = null;
        
        Test.startTest();
        Test.setMock(HttpCalloutMock.class, 
            new TokenMock(200, '{"access_token":"NEW_TOKEN_12345","expires_in":3600}')
        );
        
        String token = AdobeSignTokenUtil.getAccessToken();
        
        Test.stopTest();
        
        System.assertEquals('NEW_TOKEN_12345', token, 'Should return access token');
        System.assertNotEquals(null, AdobeSignTokenUtil.tokenExpiry, 'Token expiry should be set');
    }
    
    @isTest
    static void testTokenCaching() {
        // Set up a cached token that's still valid
        AdobeSignTokenUtil.cachedAccessToken = 'CACHED_TOKEN';
        AdobeSignTokenUtil.tokenExpiry = Datetime.now().addHours(1);
        
        Test.startTest();
        // No mock needed - should use cached token
        String token = AdobeSignTokenUtil.getAccessToken();
        Test.stopTest();
        
        System.assertEquals('CACHED_TOKEN', token, 'Should return cached token');
    }
    
    @isTest
    static void testTokenRefreshWhenExpired() {
        // Set up an expired token
        AdobeSignTokenUtil.cachedAccessToken = 'OLD_TOKEN';
        AdobeSignTokenUtil.tokenExpiry = Datetime.now().addSeconds(-10);
        
        Test.startTest();
        Test.setMock(HttpCalloutMock.class, 
            new TokenMock(200, '{"access_token":"REFRESHED_TOKEN","expires_in":3600}')
        );
        
        String token = AdobeSignTokenUtil.getAccessToken();
        
        Test.stopTest();
        
        System.assertEquals('REFRESHED_TOKEN', token, 'Should refresh and return new token');
    }
    
    @isTest
    static void testTokenRefreshNearExpiry() {
        AdobeSignTokenUtil.cachedAccessToken = 'EXPIRING_TOKEN';
        AdobeSignTokenUtil.tokenExpiry = Datetime.now().addSeconds(30);
        
        Test.startTest();
        Test.setMock(HttpCalloutMock.class, 
            new TokenMock(200, '{"access_token":"REFRESHED_EARLY","expires_in":3600}')
        );
        
        String token = AdobeSignTokenUtil.getAccessToken();
        
        Test.stopTest();
        
        System.assertEquals('REFRESHED_EARLY', token, 'Should proactively refresh token');
    }
    
    @isTest
    static void testTokenRefreshFailure() {
        AdobeSignTokenUtil.cachedAccessToken = null;
        AdobeSignTokenUtil.tokenExpiry = null;
        
        Test.startTest();
        Test.setMock(HttpCalloutMock.class, 
            new TokenMock(401, '{"error":"invalid_grant"}')
        );
        
        Boolean exceptionThrown = false;
        try {
            AdobeSignTokenUtil.getAccessToken();
        } catch (AdobeSignTokenUtil.AdobeTokenException e) {
            exceptionThrown = true;
            System.assert(e.getMessage().contains('Failed to refresh'), 
                'Exception should mention refresh failure');
        }
        
        Test.stopTest();
        
        System.assert(exceptionThrown, 'Should throw exception on failed refresh');
    }
    
    @isTest
    static void testTokenWithNullExpiresIn() {
        AdobeSignTokenUtil.cachedAccessToken = null;
        AdobeSignTokenUtil.tokenExpiry = null;
        
        Test.startTest();
        Test.setMock(HttpCalloutMock.class, 
            new TokenMock(200, '{"access_token":"TOKEN_NO_EXPIRY"}')
        );
        
        String token = AdobeSignTokenUtil.getAccessToken();
        
        Test.stopTest();
        
        System.assertEquals('TOKEN_NO_EXPIRY', token, 'Should handle missing expires_in');
        System.assert(
            AdobeSignTokenUtil.tokenExpiry > Datetime.now().addSeconds(3500),
            'Should use default 3600 seconds expiry'
        );
    }
    
    @isTest
    static void testMultipleCallsUseCachedToken() {
        AdobeSignTokenUtil.cachedAccessToken = null;
        AdobeSignTokenUtil.tokenExpiry = null;
        
        Test.startTest();
        Test.setMock(HttpCalloutMock.class, 
            new TokenMock(200, '{"access_token":"SHARED_TOKEN","expires_in":3600}')
        );
        
        String token1 = AdobeSignTokenUtil.getAccessToken();
        String token2 = AdobeSignTokenUtil.getAccessToken();
        String token3 = AdobeSignTokenUtil.getAccessToken();
        
        Test.stopTest();
        
        System.assertEquals(token1, token2, 'Second call should use cached token');
        System.assertEquals(token2, token3, 'Third call should use cached token');
    }
}