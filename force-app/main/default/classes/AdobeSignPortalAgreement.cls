/**
 * @description
 *  Queueable Adobe Sign integration for portal FA agreements.
 *  - Creates agreement via Adobe REST API
 *  - Creates resource-scoped webhook for that specific agreement
 *  - Chains to AccountUpdateJob to save agreement ID 
 *  - Chains to URL fetcher to get signing URLs
 */
public without sharing class AdobeSignPortalAgreement
    implements Queueable, Database.AllowsCallouts {

    private static final String  API_USER_EMAIL            = getConfig().Adobe_API_User__c;
    private static final String  CLASS_NAME                = 'AdobeSignPortalAgreement';
    private static final Integer AGREEMENT_EXPIRATION_DAYS = 30;

    // ===== Helper: config + base URL ================================
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
            throw new AdobeConfigException('Adobe integration config CMDT not found.');
        }
        return configs[0];
    }

    private static String buildApiUrl(String relativePath) {
        Adobe_Integration_Config__mdt cfg = getConfig();
        String base = cfg.Api_Base_Url__c;
        if (String.isBlank(base)) {
            throw new AdobeConfigException('Api_Base_Url__c is blank in Adobe config.');
        }
        if (!base.endsWith('/')) {
            base += '/';
        }
        String apiRoot = base + 'api/rest/v6/';
        if (relativePath.startsWith('/')) {
            relativePath = relativePath.substring(1);
        }
        return apiRoot + relativePath;
    }

    public class AdobeConfigException extends Exception {}

    // ===== Flow I/O DTOs =====================================================
    public class FlowSendInput {
        @InvocableVariable(required=true)
        public Id accountId;

        @InvocableVariable(required=true)
        public String libraryDocumentId;

        @InvocableVariable
        public String recipientEmail;

        @InvocableVariable
        public String agreementName;
    }

    public class FlowSendOutput {
        @InvocableVariable public Integer statusCode;
        @InvocableVariable public String  rawResponse;
        @InvocableVariable public String  documentKey;
    }

    // ===== Queueable state ===================================================
    private List<FlowSendInput> jobInputs;

    public AdobeSignPortalAgreement(List<FlowSendInput> inputs) {
        this.jobInputs = inputs;
    }

    // ===== Invocable entry-point for Flow ====================================
    @InvocableMethod(label='Send Adobe Sign Portal Agreement (Queueable)')
    public static List<FlowSendOutput> sendPortalAgreementForFlow(
        List<FlowSendInput> inputs
    ) {
        if (inputs == null || inputs.isEmpty()) {
            return new List<FlowSendOutput>();
        }

        System.enqueueJob(new AdobeSignPortalAgreement(inputs));

        List<FlowSendOutput> results = new List<FlowSendOutput>();
        for (FlowSendInput i : inputs) {
            FlowSendOutput out = new FlowSendOutput();
            out.statusCode  = 202;
            out.rawResponse = 'QUEUED_FOR_PROCESSING';
            out.documentKey = null;
            results.add(out);
        }
        return results;
    }

    // ===== Queueable execution ===============================================
    public void execute(QueueableContext qc) {
        if (jobInputs == null || jobInputs.isEmpty()) return;

        for (FlowSendInput input : jobInputs) {
            if (input == null || input.accountId == null) continue;

            try {
                // STEP 1: Create agreement (callout)
                FlowSendOutput result = sendOne(input);

                if (result != null && !String.isBlank(result.documentKey)) {
                    
                    // STEP 2: Create resource-scoped webhook (callout)
                    // This can fail silently for INVALID_WEBHOOK_URL
                    String webhookId = createResourceWebhook(result.documentKey, input.accountId);

                    // STEP 3: Chain to AccountUpdateJob (DML in separate transaction)
                    // This avoids "uncommitted work pending" error
                    System.enqueueJob(
                        new AccountUpdateJob(
                            input.accountId,
                            result.documentKey
                        )
                    );
                }
            } catch (Exception e) {
                AdobeFaErrorLogUtil.logError(
                    CLASS_NAME,
                    'execute',
                    e,
                    input.accountId
                );
            }
        }
    }

    // ===== Create resource-scoped webhook ====================================
    private static String createResourceWebhook(String agreementId, Id accountId) {
        Adobe_Integration_Config__mdt cfg = getConfig();
        String webhookUrl = cfg.Webhook_Url__c;
        if (String.isBlank(webhookUrl)) {
            throw new AdobeConfigException('Webhook_Url__c is blank in Adobe config.');
        }

        Map<String, Object> webhookInfo = new Map<String, Object>{
            'name' => 'Portal Agreement Webhook - ' + agreementId.substring(0, 10),
            'scope' => 'RESOURCE',
            'resourceType' => 'AGREEMENT',
            'resourceId' => agreementId,
            'state' => 'ACTIVE',
            'webhookSubscriptionEvents' => new List<String>{
                'AGREEMENT_ALL'
            },
            'webhookUrlInfo' => new Map<String, Object>{
                'url' => webhookUrl
            }
        };

        String bodyJson = JSON.serialize(webhookInfo);
        String endpoint = buildApiUrl('webhooks');

        HttpRequest req = new HttpRequest();
        req.setEndpoint(endpoint);
        req.setMethod('POST');
        req.setHeader('Content-Type', 'application/json');
        req.setHeader('Authorization', 'Bearer ' + AdobeSignTokenUtil.getAccessToken());
        req.setHeader('x-api-user', 'email:' + API_USER_EMAIL);
        req.setBody(bodyJson);

        Http http = new Http();
        HttpResponse res = http.send(req);

        if (res.getStatusCode() >= 200 && res.getStatusCode() < 300) {
            Map<String, Object> response =
                (Map<String, Object>) JSON.deserializeUntyped(res.getBody());
            return (String) response.get('id');
        } else {
            // swallow INVALID_WEBHOOK_URL without logging API_ERROR
            String body = res.getBody();
            try {
                if (!String.isBlank(body)) {
                    Map<String, Object> err =
                        (Map<String, Object>) JSON.deserializeUntyped(body);
                    String errCode = (String) err.get('code');
                    if ('INVALID_WEBHOOK_URL'.equals(errCode)) {
                        return null;
                    }
                }
            } catch (Exception ignore) {
            }

            AdobeFaErrorLogUtil.logApiError(
                CLASS_NAME,
                'createResourceWebhook',
                res,
                accountId,
                bodyJson
            );
            return null;
        }
    }

    // ===== NEW: Separate queueable for Account DML ==========================
    public class AccountUpdateJob implements Queueable {
        private Id accountId;
        private String agreementId;
        
        public AccountUpdateJob(Id accountId, String agreementId) {
            this.accountId = accountId;
            this.agreementId = agreementId;
        }
        
        public void execute(QueueableContext qc) {
            try {
                // Update Account with agreement ID and initial status
                update new Account(
                    Id = accountId,
                    FA_Portal_AgreementId__c      = agreementId,
                    FA_Portal_Agreement_Status__c = 'Out for Signature'
                );
                
                // Chain URL fetcher to get signing URLs
                System.enqueueJob(
                    new AdobeSignPortalAgreementUrl(accountId)
                );
                
            } catch (Exception e) {
                AdobeFaErrorLogUtil.logError(
                    CLASS_NAME,
                    'AccountUpdateJob.execute',
                    e,
                    accountId,
                    null,
                    'AgreementId: ' + agreementId,
                    AdobeFaErrorLogUtil.ErrorType.SYSTEM_ERROR
                );
            }
        }
    }

    // ===== Core implementation: create agreement =============================
    private static FlowSendOutput sendOne(FlowSendInput input) {

        // 1) Load Account data
        Account acc = [
            SELECT Id,
                   Name,
                   Email__c,
                   PersonEmail,
                   Type_of_Case_A__c,
                   Total_Fee_Agreement_Amount__c,
                   Responsible_Attorney__r.Email,
                   Responsible_Attorney__r.Name
            FROM Account
            WHERE Id = :input.accountId
            LIMIT 1
        ];

        // Resolve portal signer email
        String portalEmail = input.recipientEmail;
        if (String.isBlank(portalEmail)) {
            portalEmail = !String.isBlank(acc.Email__c)
                ? acc.Email__c
                : acc.PersonEmail;
        }

        // Attorney signer email
        String attyEmail =
            acc.Responsible_Attorney__r == null
                ? null
                : acc.Responsible_Attorney__r.Email;

        // 2) Build mergeFieldInfo
        Map<String, Object> mergeFields = new Map<String, Object>{
            'Client Name'           => acc.Name,
            'Type of Case'          => acc.Type_of_Case_A__c,
            'Email'                 => portalEmail,
'Retainer' => acc.Total_Fee_Agreement_Amount__c == null
    ? null
    : String.valueOf(acc.Total_Fee_Agreement_Amount__c),
            'Responsible Attorney'  => acc.Responsible_Attorney__r == null
                                       ? null
                                       : acc.Responsible_Attorney__r.Name
        };

        List<Object> mergeFieldInfo = new List<Object>();
        for (String fieldName : mergeFields.keySet()) {
            Object val = mergeFields.get(fieldName);
            if (val == null) continue;
            mergeFieldInfo.add(
                new Map<String, Object>{
                    'fieldName'    => fieldName,
                    'defaultValue' => String.valueOf(val)
                }
            );
        }

        // 3) Build participantSetsInfo
        List<Object> participantSetsInfo = new List<Object>();

        if (!String.isBlank(portalEmail)) {
            participantSetsInfo.add(
                new Map<String, Object>{
                    'role'        => 'SIGNER',
                    'order'       => 1,
                    'memberInfos' => new List<Object>{
                        new Map<String, Object>{ 'email' => portalEmail }
                    }
                }
            );
        }

        if (!String.isBlank(attyEmail)) {
            participantSetsInfo.add(
                new Map<String, Object>{
                    'role'        => 'SIGNER',
                    'order'       => 2,
                    'memberInfos' => new List<Object>{
                        new Map<String, Object>{ 'email' => attyEmail }
                    }
                }
            );
        }

        // 4) Email options
        Map<String, Object> emailOption = new Map<String, Object>{
            'sendOptions' => new Map<String, Object>{
                'initEmails'       => 'NONE',
                'inFlightEmails'   => 'ALL',
                'completionEmails' => 'ALL'
            }
        };

        // 5) Expiration timestamp (30 days from now, UTC)
        DateTime expiration    = System.now().addDays(AGREEMENT_EXPIRATION_DAYS);
        String   expirationIso = expiration.formatGmt('yyyy-MM-dd\'T\'HH:mm:ss\'Z\'');

        // 6) Build /agreements request body
        String name = String.isBlank(input.agreementName)
            ? 'Fee Agreement Modern Family Law ' + acc.Name
            : input.agreementName;

        Map<String, Object> bodyMap = new Map<String, Object>{
            'name'               => name,
            'state'              => 'IN_PROCESS',
            'signatureType'      => 'ESIGN',
            'fileInfos'          => new List<Object>{
                new Map<String, Object>{
                    'libraryDocumentId' => input.libraryDocumentId
                }
            },
            'participantSetsInfo'=> participantSetsInfo,
            'emailOption'        => emailOption,
            'mergeFieldInfo'     => mergeFieldInfo,
            'expirationTime'     => expirationIso
        };

        String bodyJson = JSON.serialize(bodyMap);

        // 7) Call Adobe agreements
        HttpRequest req = new HttpRequest();
        req.setEndpoint(buildApiUrl('agreements'));
        req.setMethod('POST');
        req.setHeader('Content-Type', 'application/json');
        req.setHeader('Authorization', 'Bearer ' + AdobeSignTokenUtil.getAccessToken());
        req.setHeader('x-api-user', 'email:' + API_USER_EMAIL);
        req.setBody(bodyJson);

        Http http = new Http();
        HttpResponse res = http.send(req);

        // 8) Handle response
        FlowSendOutput out = new FlowSendOutput();
        out.statusCode  = res.getStatusCode();
        out.rawResponse = res.getBody();

        if (out.statusCode >= 200 && out.statusCode < 300) {
            Map<String, Object> resp =
                (Map<String, Object>) JSON.deserializeUntyped(res.getBody());
            out.documentKey = (String) resp.get('id');
        } else {
            AdobeFaErrorLogUtil.logApiError(
                CLASS_NAME,
                'sendOne',
                res,
                input.accountId,
                bodyJson
            );
        }

        return out;
    }

    public static String getSigningUrl(String agreementId) {
        return getSigningUrl(agreementId, true);
    }

    public static String getSigningUrl(String agreementId, Boolean logApiError) {
        if (String.isBlank(agreementId)) {
            return null;
        }

        HttpRequest req = new HttpRequest();
        String relPath =
            'agreements/' +
            EncodingUtil.urlEncode(agreementId, 'UTF-8') +
            '/signingUrls';
        req.setEndpoint(buildApiUrl(relPath));
        req.setMethod('GET');
        req.setHeader('Authorization', 'Bearer ' + AdobeSignTokenUtil.getAccessToken());
        req.setHeader('x-api-user', 'email:' + API_USER_EMAIL);

        Http http = new Http();
        HttpResponse res = http.send(req);

        if (res.getStatusCode() < 200 || res.getStatusCode() >= 300) {
            if (logApiError == true) {
                AdobeFaErrorLogUtil.logApiError(
                    CLASS_NAME,
                    'getSigningUrl',
                    res,
                    null,
                    'Agreement ID: ' + agreementId
                );
            }
            return null;
        }

        Map<String, Object> resp =
            (Map<String, Object>) JSON.deserializeUntyped(res.getBody());

        List<Object> setInfos =
            (List<Object>) resp.get('signingUrlSetInfos');
        if (setInfos == null || setInfos.isEmpty()) {
            return null;
        }

        Map<String, Object> firstSet =
            (Map<String, Object>) setInfos[0];
        List<Object> signingUrls =
            (List<Object>) firstSet.get('signingUrls');
        if (signingUrls == null || signingUrls.isEmpty()) {
            return null;
        }

        Map<String, Object> firstUrl =
            (Map<String, Object>) signingUrls[0];

        String url = (String) firstUrl.get('esignUrl');
        return url;
    }
}