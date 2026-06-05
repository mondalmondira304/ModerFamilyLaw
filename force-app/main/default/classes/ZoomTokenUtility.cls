public class ZoomTokenUtility {

    @future(callout=true)
    public static void refreshZoomTokensAsync() {
        refreshAccessToken();
    }

    // Method to refresh tokens and return the new access token
    public static String refreshAccessToken() {
        try {
            // Step 1: Perform the callout to get a new access token using the refresh token
            HttpRequest req = new HttpRequest();
            req.setEndpoint('https://zoom.us/oauth/token');
            req.setMethod('POST');

            // Retrieve clientId and clientSecret from Custom Setting
            ZccCredentials__c zoomCred = ZccCredentials__c.getInstance();
            String clientId = zoomCred.ClientId__c;
            String clientSecret = zoomCred.ClientSecret__c;

            // Manually encode the client_id and client_secret
            String encodedCredentials = EncodingUtil.base64Encode(
                Blob.valueOf(clientId + ':' + clientSecret)
            );
            req.setHeader('Authorization', 'Basic ' + encodedCredentials);
            req.setHeader('Content-Type', 'application/x-www-form-urlencoded');

            // Retrieve the refresh token from custom settings
            String refreshToken = getRefreshTokenFromCustomSetting();
            System.debug('Using Refresh Token: ' + refreshToken);

            req.setBody('grant_type=refresh_token&refresh_token=' + refreshToken);

            // Send the HTTP request (perform the callout)
            Http http = new Http();
            HttpResponse res = http.send(req);

            // Log the response status and body
            System.debug('Response Status Code: ' + res.getStatusCode());
            System.debug('Response Body: ' + res.getBody());

            // Step 2: Handle the response and update custom settings with new tokens
            if (res.getStatusCode() == 200) {
                // Parse the response JSON to extract the access token and the new refresh token
                Map<String, Object> responseMap = (Map<String, Object>) JSON.deserializeUntyped(res.getBody());

                // Extract tokens
                String newAccessToken = (String) responseMap.get('access_token');
                String newRefreshToken = (String) responseMap.get('refresh_token');

                // Update tokens in custom settings
                updateZoomTokens(newAccessToken, newRefreshToken);

                // Return the new access token
                System.debug('New Access Token Retrieved: ' + newAccessToken);
                return newAccessToken;
            } else {
                System.debug('Failed to refresh token. Response: ' + res.getBody());
                return null;
            }
        } catch (Exception e) {
            System.debug('Exception occurred during token refresh: ' + e.getMessage());
            return null;
        }
    }

    // Method to update tokens in custom settings
    public static void updateZoomTokens(String accessToken, String refreshToken) {
        ZccCredentials__c zoomCred = ZccCredentials__c.getInstance();
        if (zoomCred == null) {
            zoomCred = new ZccCredentials__c();
        }

        // Store access token in parts
        if (accessToken.length() > 255) {
            zoomCred.Access_Token_Part1__c = accessToken.substring(0, 255);
        } else {
            zoomCred.Access_Token_Part1__c = accessToken;
        }

        if (accessToken.length() > 510) {
            zoomCred.Access_Token_Part2__c = accessToken.substring(255, 510);
            zoomCred.Access_Token_Part3__c = accessToken.substring(510);
        } else if (accessToken.length() > 255) {
            zoomCred.Access_Token_Part2__c = accessToken.substring(255);
        }

        // Store refresh token in parts
        if (refreshToken.length() > 255) {
            zoomCred.Refresh_Token_Part1__c = refreshToken.substring(0, 255);
        } else {
            zoomCred.Refresh_Token_Part1__c = refreshToken;
        }

        if (refreshToken.length() > 510) {
            zoomCred.Refresh_Token_Part2__c = refreshToken.substring(255, 510);
            zoomCred.Refresh_Token_Part3__c = refreshToken.substring(510);
        } else if (refreshToken.length() > 255) {
            zoomCred.Refresh_Token_Part2__c = refreshToken.substring(255);
        }

        upsert zoomCred;
        System.debug('Tokens successfully updated in custom settings: ' + zoomCred);
    }

    // Helper method to retrieve refresh token from the custom setting
    public static String getRefreshTokenFromCustomSetting() {
        ZccCredentials__c zoomCred = ZccCredentials__c.getInstance();
        String refreshToken = '';

        if (zoomCred != null) {
            if (zoomCred.Refresh_Token_Part1__c != null) refreshToken += zoomCred.Refresh_Token_Part1__c;
            if (zoomCred.Refresh_Token_Part2__c != null) refreshToken += zoomCred.Refresh_Token_Part2__c;
            if (zoomCred.Refresh_Token_Part3__c != null) refreshToken += zoomCred.Refresh_Token_Part3__c;
        }

        return refreshToken;
    }

    // Method to retrieve the Access Token, refreshing it if needed
    public static String getAccessToken() {
        // Refresh the access token every time to ensure it's fresh
        String accessToken = refreshAccessToken();
        if (accessToken != null) {
            System.debug('Access Token Retrieved from refreshAccessToken: ' + accessToken);
        } else {
            System.debug('Failed to retrieve new Access Token.');
        }
        return accessToken;
    }
}