public class timesolvIntegrationTokenUtil {
    @TestVisible private static Boolean skipTestCheck = false;

    private static String        cachedToken;
    private static Datetime      tokenExpiry;
    private static final Integer MAX_RETRIES    = 3;

    @TestVisible  static String   baseUrlStatic;
    @TestVisible  static TimeSolv_Integration_Configuration__mdt configStatic;
    static {
        List<TimeSolv_Integration_Configuration__mdt> cfgs = [
            SELECT Endpoint_URL__c,
                   Client_ID__c,
                   Client_Secret__c,
                   Auth_Code__c,
                   Redirect_URI__c
              FROM TimeSolv_Integration_Configuration__mdt
             WHERE DeveloperName = 'Production'
             LIMIT 1
        ];
        if (!cfgs.isEmpty()) {
            configStatic = cfgs[0];
            baseUrlStatic = configStatic.Endpoint_URL__c;
        } else {
            configStatic = null;
            baseUrlStatic = '';
        }
    }

    public static String getBearerToken() {
        if (!skipTestCheck && Test.isRunningTest()) {
            return 'TEST_TOKEN';
        }

        if (String.isBlank(baseUrlStatic)) {
            throw new TokenRetrievalException(
                'TimeSolv URL not configured. Check TimeSolv_Integration_Configuration__mdt.');
        }
        if (configStatic == null) {
            throw new TokenRetrievalException(
                'TimeSolv integration configuration not found. Check TimeSolv_Integration_Configuration__mdt.');
        }

        String body = 
            'client_id='      + configStatic.Client_ID__c +
            '&client_secret=' + configStatic.Client_Secret__c +
            '&grant_type=authorization_code' +
            '&code='          + configStatic.Auth_Code__c +
            '&redirect_uri='  + configStatic.Redirect_URI__c;

        Http http = new Http();
        for (Integer attempt = 1; attempt <= MAX_RETRIES; attempt++) {
            HttpRequest req = new HttpRequest();
            req.setEndpoint(baseUrlStatic + '/token');
            req.setMethod('POST');
            req.setHeader('Content-Type', 'application/x-www-form-urlencoded');
            req.setTimeout(3000); 
            req.setBody(body);

            System.debug(LoggingLevel.INFO, 'Token request attempt ' + attempt);
            HttpResponse res = http.send(req);

            if (res.getStatusCode() == 200) {
                TokenAPIResponse tok = 
                    (TokenAPIResponse) JSON.deserialize(res.getBody(), TokenAPIResponse.class);
                cachedToken = tok.access_token;
                Integer mins = (tok.expires_in != null && tok.expires_in > 0)
                               ? Math.min(tok.expires_in/60 - 5, 55)
                               : 55;
                tokenExpiry = Datetime.now().addMinutes(mins);
                return cachedToken;
            } else {
                System.debug(LoggingLevel.WARN, 
                    'Attempt ' + attempt + ' failed: ' + res.getStatusCode());
            }
        }

        throw new TokenRetrievalException(
            'Unable to retrieve bearer token after ' + MAX_RETRIES + ' attempts.');
    }

    @TestVisible public static String getTimesolvBaseUrl() {
        return baseUrlStatic;
    }

    @TestVisible public static TimeSolv_Integration_Configuration__mdt getIntegrationConfig() {
        return configStatic;
    }

    public class TokenRetrievalException extends Exception {}
    public class TokenAPIResponse {
        public String  access_token { get; set; }
        public String  token_type   { get; set; }
        public Integer expires_in   { get; set; }
    }
}