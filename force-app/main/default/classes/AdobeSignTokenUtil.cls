public without sharing class AdobeSignTokenUtil {

    @TestVisible private static String  cachedAccessToken;
    @TestVisible private static Datetime tokenExpiry;

    private static final Integer SAFETY_SECONDS = 60;

    private static Adobe_Integration_Config__mdt getConfig() {
    List<Adobe_Integration_Config__mdt> configs = [
        SELECT Client_Id__c, Client_Secret__c, Api_Base_Url__c, 
               Auth_Base_Url__c, Refresh_Endpoint__c, Refresh_Token__c,
               Webhook_Url__c, Adobe_API_User__c
        FROM Adobe_Integration_Config__mdt 
        WHERE Is_Active__c = true 
        LIMIT 1
    ];
    if (configs.isEmpty()) {
        throw new AdobeTokenException('Adobe integration config CMDT not found.');
    }
    return configs[0];
}
    
    public static String getAccessToken() {
        if (cachedAccessToken != null &&
            tokenExpiry != null &&
            Datetime.now().addSeconds(SAFETY_SECONDS) < tokenExpiry) {

            return cachedAccessToken;
        }

        refreshAccessToken();
        return cachedAccessToken;
    }

    @TestVisible
    private static void refreshAccessToken() {
        Adobe_Integration_Config__mdt cfg = getConfig();

        if (String.isBlank(cfg.Refresh_Endpoint__c) ||
            String.isBlank(cfg.Refresh_Token__c)   ||
            String.isBlank(cfg.Client_Id__c)       ||
            String.isBlank(cfg.Client_Secret__c)) {

            throw new AdobeTokenException('Adobe config missing refresh endpoint/token/client values.');
        }

        HttpRequest req = new HttpRequest();
        req.setMethod('POST');
        req.setEndpoint(cfg.Refresh_Endpoint__c); 
        req.setHeader('Content-Type', 'application/x-www-form-urlencoded');

        String body =
            'refresh_token=' + EncodingUtil.urlEncode(cfg.Refresh_Token__c, 'UTF-8') +
            '&client_id='    + EncodingUtil.urlEncode(cfg.Client_Id__c,      'UTF-8') +
            '&client_secret='+ EncodingUtil.urlEncode(cfg.Client_Secret__c,  'UTF-8') +
            '&grant_type=refresh_token';

        req.setBody(body);

        Http http = new Http();
        HttpResponse res = http.send(req);

        if (res.getStatusCode() < 200 || res.getStatusCode() >= 300) {
            throw new AdobeTokenException(
                'Failed to refresh Adobe token. Status ' +
                res.getStatusCode() + ' body: ' + res.getBody()
            );
        }

        Map<String, Object> json =
            (Map<String, Object>) JSON.deserializeUntyped(res.getBody());

        cachedAccessToken = (String) json.get('access_token');

        Object expRaw = json.get('expires_in');
        Integer expiresIn = expRaw == null
            ? 3600
            : Integer.valueOf(String.valueOf(expRaw));

        tokenExpiry = Datetime.now().addSeconds(expiresIn);
    }

    public class AdobeTokenException extends Exception {}
}