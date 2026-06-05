/**
 * AdobeFaAgreementGet
 *
 * GET {Api_Base_Url__c}/api/rest/v6/agreements/{agreementId}
 *
 * Uses:
 * - AdobeSignTokenUtil.getAccessToken()
 * - Adobe_Integration_Config__mdt (Api_Base_Url__c, Adobe_API_User__c)
 *
 * Header:
 * - x-api-user is ALWAYS from CMDT 
 *
 * Returns:
 * - agreementStatus (from JSON "status" when available)
 * - agreementName
 */
public without sharing class AdobeFaAgreementStatus {

    private static final String API_PATH = '/api/rest/v6';
    private static final String GET_PATH_TEMPLATE = '/agreements/{0}';

    public class GetException extends Exception {}

    public class Request {
        @InvocableVariable(required=true)
        public String agreementId;
    }

    public class Result {
        @InvocableVariable public String  agreementId;
        @InvocableVariable public String  agreementName;
        @InvocableVariable public String  agreementStatus;
        @InvocableVariable public Boolean success;
        @InvocableVariable public Integer statusCode;
        @InvocableVariable public String  responseBody;
        @InvocableVariable public String  errorMessage;
    }

    @InvocableMethod(
        label='Get Adobe Sign Agreement'
        description='Gets Adobe Sign agreement details (including status) using GET /agreements/{agreementId}.'
    )
    public static List<Result> getAgreements(List<Request> requests) {
        List<Result> results = new List<Result>();
        if (requests == null || requests.isEmpty()) return results;

        Adobe_Integration_Config__mdt cfg = getConfig();
        String accessToken = AdobeSignTokenUtil.getAccessToken();

        for (Request r : requests) {
            results.add(getSingle(r, cfg, accessToken));
        }
        return results;
    }

    private static Result getSingle(Request r, Adobe_Integration_Config__mdt cfg, String accessToken) {
        Result out = new Result();
        out.agreementId = (r == null) ? null : r.agreementId;

        try {
            if (r == null || String.isBlank(r.agreementId)) {
                throw new GetException('agreementId is required.');
            }
            if (String.isBlank(cfg.Api_Base_Url__c)) {
                throw new GetException('Adobe CMDT Api_Base_Url__c is blank.');
            }
            if (String.isBlank(cfg.Adobe_API_User__c)) {
                throw new GetException('Adobe CMDT Adobe_API_User__c is blank (required for x-api-user).');
            }
            if (String.isBlank(accessToken)) {
                throw new GetException('Adobe access token is blank.');
            }

            String endpoint =
                normalizeBaseUrl(cfg.Api_Base_Url__c) +
                API_PATH +
                String.format(GET_PATH_TEMPLATE, new List<String>{
                    EncodingUtil.urlEncode(r.agreementId, 'UTF-8')
                });

            HttpRequest req = new HttpRequest();
            req.setMethod('GET');
            req.setTimeout(120000);
            req.setEndpoint(endpoint);

            req.setHeader('Accept', 'application/json');
            req.setHeader('Authorization', 'Bearer ' + accessToken);

            // CMDT ONLY (email format)
            req.setHeader('x-api-user', 'email:' + cfg.Adobe_API_User__c.trim());

            Http http = new Http();
            HttpResponse res = http.send(req);

            out.statusCode   = res.getStatusCode();
            out.responseBody = res.getBody();

            if (out.statusCode >= 200 && out.statusCode < 300) {
                out.success = true;

                if (!String.isBlank(out.responseBody)) {
                    Map<String, Object> json = (Map<String, Object>) JSON.deserializeUntyped(out.responseBody);

                    Object statusVal = json.get('status');
                    if (statusVal != null) out.agreementStatus = String.valueOf(statusVal);

                    Object nameVal = json.get('name');
                    if (nameVal != null) out.agreementName = String.valueOf(nameVal);

                    // fallback if some payload uses "state"
                    if (String.isBlank(out.agreementStatus) && json.containsKey('state')) {
                        out.agreementStatus = String.valueOf(json.get('state'));
                    }
                }
            } else {
                out.success = false;
                out.errorMessage = 'GET failed. HTTP ' + out.statusCode + ' - ' + res.getStatus();
            }

        } catch (Exception e) {
            out.success = false;
            out.errorMessage = e.getMessage();
        }

        return out;
    }

    private static Adobe_Integration_Config__mdt getConfig() {
        List<Adobe_Integration_Config__mdt> configs = [
            SELECT Api_Base_Url__c, Adobe_API_User__c, Is_Active__c
            FROM Adobe_Integration_Config__mdt
            WHERE Is_Active__c = true
            LIMIT 1
        ];
        if (configs.isEmpty()) {
            throw new GetException('Adobe integration config CMDT not found (Is_Active__c=true).');
        }
        return configs[0];
    }

    private static String normalizeBaseUrl(String baseUrl) {
        String b = baseUrl.trim();
        while (b.endsWith('/')) b = b.substring(0, b.length() - 1);
        return b;
    }
}