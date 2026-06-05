public class NetDocumentsAuth {
    // Endpoint URL
    private static final String ENDPOINT = 'https://api.vault.netvoyage.com/v1/OAuth';
    
    // Headers
    private static final String USER_AGENT = 'NDPostmanAPIs';
    private static final String ACCEPT = 'application/json';
    private static final String CONTENT_TYPE = 'application/json';
    
    // Authorization Header
 private static final String AUTHORIZATION = 'Basic ' + EncodingUtil.base64Encode(
        Blob.valueOf(Label.NetDocumentsAuthToken)  );
    
    // Method to get a new access token using the stored refresh token
    public static String obtainAccessTokenUsingStoredRefreshToken() {
        // Retrieve the refresh token from custom settings
        NetDocumentsSettings__c settings = NetDocumentsSettings__c.getOrgDefaults();
        if (settings == null || settings.Refresh_Token__c == null) {
            System.debug('NetDocumentsAuth: No refresh token available in custom settings.');
            return null;
        }
        
        String refreshToken = settings.Refresh_Token__c;
        System.debug('NetDocumentsAuth: Using stored refresh token to obtain a new access token.');

        HttpRequest req = new HttpRequest();
        req.setEndpoint(ENDPOINT);
        req.setMethod('POST');
        
        // Set Headers
        req.setHeader('User-Agent', USER_AGENT);
        req.setHeader('Accept', ACCEPT);
        req.setHeader('Authorization', AUTHORIZATION);
        req.setHeader('Content-Type', CONTENT_TYPE);
        
        // Create JSON body
        Map<String, String> bodyMap = new Map<String, String>();
        bodyMap.put('grant_type', 'refresh_token');
        bodyMap.put('refresh_token', refreshToken);
        
        String body = JSON.serialize(bodyMap);
        req.setBody(body);

        System.debug('NetDocumentsAuth: Requesting new access token with refresh token, request body: ' + body);
        
        Http http = new Http();
        HttpResponse res = http.send(req);
        
        System.debug('NetDocumentsAuth: New access token response status: ' + res.getStatus());
        System.debug('NetDocumentsAuth: New access token response body: ' + res.getBody());
        
        if (res.getStatusCode() == 200) {
            Map<String, String> tokenResponse = parseTokenResponse(res.getBody());
            if (tokenResponse != null) {
                updateTokenInSettings(tokenResponse.get('access_token'), tokenResponse.get('refresh_token'));
                return tokenResponse.get('access_token');
            }
        } else {
            System.debug('NetDocumentsAuth: Error retrieving access token using refresh token: ' + res.getStatus() + ' - ' + res.getBody());
        }
        return null;
    }

    // Method to parse token response
    private static Map<String, String> parseTokenResponse(String responseBody) {
        System.debug('NetDocumentsAuth: Parsing token response body: ' + responseBody);
        try {
            Map<String, Object> responseMap = (Map<String, Object>) JSON.deserializeUntyped(responseBody);
            
            String accessToken = (String) responseMap.get('access_token');
            String refreshToken = (String) responseMap.get('refresh_token');

            Map<String, String> tokenMap = new Map<String, String>();
            tokenMap.put('access_token', accessToken);
            tokenMap.put('refresh_token', refreshToken);

            return tokenMap;
        } catch (Exception e) {
            System.debug('NetDocumentsAuth: Error parsing token response: ' + e.getMessage());
            return null;
        }
    }

    // Method to update token in custom settings
    public static void updateTokenInSettings(String accessToken, String refreshToken) {
        System.debug('NetDocumentsAuth: Storing tokens in custom settings.');
        NetDocumentsSettings__c settings = NetDocumentsSettings__c.getOrgDefaults();
        if (settings == null) {
            settings = new NetDocumentsSettings__c();
        }
        settings.Access_Token__c = accessToken;
        settings.Refresh_Token__c = refreshToken;
        upsert settings;
        System.debug('NetDocumentsAuth: Tokens stored in custom settings: ' + settings);
    }

    // Method to get token from custom settings
    public static Map<String, Object> getTokenFromSettings() {
        System.debug('NetDocumentsAuth: Fetching token from custom settings.');
        NetDocumentsSettings__c settings = NetDocumentsSettings__c.getOrgDefaults();
        if (settings == null) {
            System.debug('NetDocumentsAuth: Custom settings instance is null.');
            return new Map<String, Object>();
        }
        Map<String, Object> tokenInfo = new Map<String, Object>();
        tokenInfo.put('access_token', settings.Access_Token__c);
        tokenInfo.put('refresh_token', settings.Refresh_Token__c);
        System.debug('NetDocumentsAuth: Retrieved tokens from custom settings: ' + tokenInfo);
        return tokenInfo;
    }
}