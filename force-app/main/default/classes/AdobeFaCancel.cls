/**
 * AdobeFaCancel
 *
 * PUT {Api_Base_Url__c}/api/rest/v6/agreements/{agreementId}/state
 *
 * Uses:
 * - AdobeSignTokenUtil.getAccessToken()
 * - Adobe_Integration_Config__mdt (Api_Base_Url__c, Adobe_API_User__c)
 *
 * Header:
 * - x-api-user is ALWAYS from CMDT and sent as "email:<CMDT email>"
 *
 * Body:
 * {
 *   "agreementCancellationInfo": { "comment": "...", "notifyOthers": true },
 *   "state": "CANCELLED"
 * }
 */
public without sharing class AdobeFaCancel {

    private static final String CLASS_NAME = 'AdobeFaCancel';
    private static final String API_PATH = '/api/rest/v6';
    private static final String STATE_PATH_TEMPLATE = '/agreements/{0}/state';
    private static final String METHOD_CANCEL_SINGLE = 'cancelSingle';

    @TestVisible private static Adobe_Integration_Config__mdt testConfigOverride;
    @TestVisible private static String testAccessTokenOverride;

    public class CancelException extends Exception {}

    public class Request {
        @InvocableVariable(required=true)
        public String agreementId;

        @InvocableVariable(required=false)
        public String comment;

        @InvocableVariable(required=false)
        public Boolean notifyOthers;
    }

    public class Result {
        @InvocableVariable public String  agreementId;
        @InvocableVariable public Boolean success;
        @InvocableVariable public Integer statusCode;
        @InvocableVariable public String  responseBody;
        @InvocableVariable public String  errorMessage;
    }

    private class AgreementCancellationInfo {
        public String  comment;
        public Boolean notifyOthers;
    }

    private class Payload {
        public AgreementCancellationInfo agreementCancellationInfo;
        public String state;
    }

    @InvocableMethod(
        label='Cancel Adobe Sign Agreement'
        description='Cancels an Adobe Sign agreement using PUT /agreements/{agreementId}/state.'
    )
    public static List<Result> cancelFromFlow(List<Request> requests) {
        List<Result> results = new List<Result>();
        if (requests == null || requests.isEmpty()) return results;

        Adobe_Integration_Config__mdt cfg = getConfig();
        String accessToken = getAccessToken();
        Integer calloutsRemaining = Limits.getLimitCallouts() - Limits.getCallouts();

        for (Request r : requests) {
            if (calloutsRemaining <= 0) {
                Result out = new Result();
                out.agreementId = (r == null) ? null : r.agreementId;
                out.success = false;
                out.errorMessage = 'Cancel skipped: callout governor limit reached for this transaction.';
                results.add(out);
                continue;
            }
            results.add(cancelSingle(r, cfg, accessToken));
            calloutsRemaining--;
        }
        return results;
    }

    private static Result cancelSingle(Request r, Adobe_Integration_Config__mdt cfg, String accessToken) {
        Result out = new Result();
        out.agreementId = (r == null) ? null : r.agreementId;
        String requestBody = null;

        try {
            if (r == null || String.isBlank(r.agreementId)) {
                throw new CancelException('agreementId is required.');
            }
            if (String.isBlank(cfg.Api_Base_Url__c)) {
                throw new CancelException('Adobe CMDT Api_Base_Url__c is blank.');
            }
            if (String.isBlank(cfg.Adobe_API_User__c)) {
                throw new CancelException('Adobe CMDT Adobe_API_User__c is blank (required for x-api-user).');
            }
            if (String.isBlank(accessToken)) {
                throw new CancelException('Adobe access token is blank.');
            }

            String endpoint =
                normalizeBaseUrl(cfg.Api_Base_Url__c) +
                API_PATH +
                String.format(STATE_PATH_TEMPLATE, new List<String>{
                    EncodingUtil.urlEncode(r.agreementId, 'UTF-8')
                });

            HttpRequest req = new HttpRequest();
            req.setMethod('PUT');
            req.setTimeout(120000);
            req.setEndpoint(endpoint);

            req.setHeader('Content-Type', 'application/json');
            req.setHeader('Accept', 'application/json');
            req.setHeader('Authorization', 'Bearer ' + accessToken);

            // CMDT ONLY (email format)
            req.setHeader('x-api-user', 'email:' + cfg.Adobe_API_User__c.trim());

            Payload payload = new Payload();
            payload.state = 'CANCELLED';
            payload.agreementCancellationInfo = new AgreementCancellationInfo();
            payload.agreementCancellationInfo.notifyOthers =
                (r.notifyOthers == null) ? true : r.notifyOthers;

            // comment optional; if blank, omit it
            if (!String.isBlank(r.comment)) {
                payload.agreementCancellationInfo.comment = r.comment;
            }

            requestBody = JSON.serialize(payload);
            req.setBody(requestBody);

            Http http = new Http();
            HttpResponse res = http.send(req);

            out.statusCode   = res.getStatusCode();
            out.responseBody = res.getBody();

            out.success = (out.statusCode >= 200 && out.statusCode < 300);
            if (!out.success) {
                out.errorMessage = 'Cancel failed. HTTP ' + out.statusCode + ' - ' + res.getStatus();
                AdobeFaErrorLogUtil.logApiError(
                    CLASS_NAME,
                    METHOD_CANCEL_SINGLE,
                    res,
                    null,
                    requestBody
                );
            }

        } catch (Exception e) {
            out.success = false;
            out.errorMessage = e.getMessage();
            AdobeFaErrorLogUtil.logError(
                CLASS_NAME,
                METHOD_CANCEL_SINGLE,
                e,
                null,
                null,
                requestBody,
                getErrorType(e)
            );
        }

        return out;
    }

    private static String getAccessToken() {
        if (Test.isRunningTest() && testAccessTokenOverride != null) {
            return testAccessTokenOverride;
        }
        return AdobeSignTokenUtil.getAccessToken();
    }

    private static Adobe_Integration_Config__mdt getConfig() {
        if (Test.isRunningTest() && testConfigOverride != null) {
            return testConfigOverride;
        }
        List<Adobe_Integration_Config__mdt> configs = [
            SELECT Api_Base_Url__c, Adobe_API_User__c, Is_Active__c
            FROM Adobe_Integration_Config__mdt
            WHERE Is_Active__c = true
            LIMIT 1
        ];
        if (configs.isEmpty()) {
            throw new CancelException('Adobe integration config CMDT not found (Is_Active__c=true).');
        }
        return configs[0];
    }

    private static String normalizeBaseUrl(String baseUrl) {
        String b = baseUrl.trim();
        while (b.endsWith('/')) b = b.substring(0, b.length() - 1);
        return b;
    }

    private static AdobeFaErrorLogUtil.ErrorType getErrorType(Exception e) {
        if (e instanceof CancelException) {
            String message = e.getMessage();
            if (message != null && message.contains('agreementId is required')) {
                return AdobeFaErrorLogUtil.ErrorType.DATA_ERROR;
            }
            return AdobeFaErrorLogUtil.ErrorType.CONFIGURATION_ERROR;
        }
        return AdobeFaErrorLogUtil.ErrorType.SYSTEM_ERROR;
    }
}