/**
 * AdobeSignWebhookHandler
 * 
 * Handles incoming webhook notifications from Adobe Sign.
 * Processes agreement lifecycle events and updates Salesforce Account records.
 * 
 * Participant Order: 1 = Client (signs first), 2 = Attorney (signs second)
 * 
 * Status Flow:
 * Out for Signature → Client Signed → Client Signed-Waiting Atty → 
 * Atty Signed → All Signed → FA Downloaded
 * 
 * Terminal States: Completed, Cancelled, Expired, Declined
 * (No further processing occurs once terminal state reached)
 */
@RestResource(urlMapping='/adobeSignWebhook/*')
global without sharing class AdobeSignWebhookHandler {
    
    private static final String CLASS_NAME = 'AdobeSignWebhookHandler';
    private static final String HEADER_CLIENT_ID = 'X-AdobeSign-ClientId';
    private static final String HEADER_CHALLENGE = 'x-adobesign-webhook-challenge';
    private static Boolean retryJobExecuting = false;
    
    private static final Set<String> TERMINAL_STATUSES = new Set<String>{
        'FA_Downloaded', 'Cancelled', 'Expired', 'Declined'
    };
    
    private static final Set<String> LOGGABLE_EVENTS = new Set<String>{
        'AGREEMENT_CREATED',
        'AGREEMENT_ACTION_REQUESTED',
        'AGREEMENT_ACTION_COMPLETED',
        'AGREEMENT_WORKFLOW_COMPLETED'
    };

    /**
     * One-time schedulable wrapper to delay RetryJob.
     */
    global class RetryJobSchedulable implements Schedulable {
        private String docKey;
        private String eventName;
        private Integer participantOrder;
        private Integer attempt;
        private String webhookId;

        public RetryJobSchedulable(
            String docKey,
            String eventName,
            Integer participantOrder,
            Integer attempt,
            String webhookId
        ) {
            this.docKey = docKey;
            this.eventName = eventName;
            this.participantOrder = participantOrder;
            this.attempt = attempt;
            this.webhookId = webhookId;
        }

        public void execute(SchedulableContext sc) {
            System.enqueueJob(new RetryJob(docKey, eventName, participantOrder, attempt, webhookId));
        }
    }

    @TestVisible
    private static void scheduleRetryInMinutes(
        String docKey,
        String eventName,
        Integer participantOrder,
        Integer nextAttempt,
        String webhookId,
        Integer minutesFromNow
    ) {
        Datetime dt = System.now().addMinutes(Math.max(1, minutesFromNow));

        String cron =
            String.valueOf(dt.second()) + ' ' +
            String.valueOf(dt.minute()) + ' ' +
            String.valueOf(dt.hour())   + ' ' +
            String.valueOf(dt.day())    + ' ' +
            String.valueOf(dt.month())  + ' ? ' +
            String.valueOf(dt.year());

        String key10 = (String.isBlank(docKey))
            ? 'NO_KEY'
            : docKey.substring(0, Math.min(10, docKey.length()));

        String jobName = 'AdobeRetry_' + key10
                       + '_' + String.valueOf(nextAttempt)
                       + '_' + String.valueOf(dt.getTime());

        System.schedule(
            jobName,
            cron,
            new RetryJobSchedulable(docKey, eventName, participantOrder, nextAttempt, webhookId)
        );
    }
    
    /**
     * Retrieves Adobe Sign Client ID from Custom Metadata Type.
     * Uses SOQL for reliability in queueable contexts.
     */
    private static String getValidClientIdFromConfig() {
        List<Adobe_Integration_Config__mdt> configs = [
            SELECT Client_Id__c
            FROM Adobe_Integration_Config__mdt 
            WHERE Is_Active__c = true 
            LIMIT 1
        ];
        return configs.isEmpty() ? null : configs[0].Client_Id__c;
    }
    
    /**
     * GET handler - Webhook URL verification from Adobe Sign.
     * Must return 200 and echo back the Client ID.
     */
    @HttpGet
    global static String handleGetRequest() {
        RestResponse res = RestContext.response;
        RestRequest req = RestContext.request;
        
        String incomingId = req.headers.get(HEADER_CLIENT_ID);
        String configClientId = getValidClientIdFromConfig();
        String responseClientId = !String.isBlank(incomingId) ? incomingId : configClientId;
        
        if (String.isBlank(responseClientId)) {
            res.statusCode = 400;
            res.addHeader('Content-Type', 'application/json');
            return '{"success":false,"message":"Missing Adobe client id"}';
        }
        
        res.statusCode = 200;
        res.addHeader('Content-Type', 'application/json');
        res.addHeader(HEADER_CLIENT_ID, responseClientId);
        return '{"xAdobeSignClientId":"' + responseClientId + '"}';
    }
    
    /**
     * POST handler - Main webhook event processor.
     * 
     * Handles: Agreement creation, signing events, completion, cancellation
     * Terminal State Guard: Stops processing if agreement already completed
     * Triggers: PDF download job when all parties sign
     */
    @HttpPost
    global static String handleWebhook() {
        RestResponse res = RestContext.response;
        RestRequest req = RestContext.request;
        
        Integer bodySize = (req.requestBody != null) ? req.requestBody.size() : 0;
        
        // Reject oversized payloads
        if (bodySize > 5000000) { 
            AdobeFaErrorLogUtil.logError(
                CLASS_NAME, 'handleWebhook', null, null, null,
                'Webhook body too large: ' + bodySize + ' bytes',
                AdobeFaErrorLogUtil.ErrorType.SYSTEM_ERROR
            );
            res.statusCode = 200; 
            return '{"success":false,"error":"Payload too large"}';
        }
        
        String body = (req.requestBody != null) ? req.requestBody.toString() : '';
        String incomingId = req.headers.get(HEADER_CLIENT_ID);
        String challenge = req.headers.get(HEADER_CHALLENGE);
        
        // Echo Client ID on every response
        String clientIdToEcho = !String.isBlank(incomingId) ? incomingId : getValidClientIdFromConfig();
        if (!String.isBlank(clientIdToEcho)) {
            res.addHeader(HEADER_CLIENT_ID, clientIdToEcho);
        }
        
        Portal_FA_Event_Log__c logRec;
        
        // Handle challenge-response handshake
        if (challenge != null) {
            res.statusCode = 200;
            return challenge; 
        }
        
        // Handle empty body (health check)
        if (String.isBlank(body)) {
            res.statusCode = 200;
            return '{"success":true,"message":"empty body"}';
        }
        
        try {
            Map<String, Object> payload = (Map<String, Object>) JSON.deserializeUntyped(body);
            
            String webhookId = (String) payload.get('webhookId');
            String event = (String) payload.get('event');
            String participantUserId = (String) payload.get('participantUserId');
            String participantEmail = (String) payload.get('participantUserEmail');
            String eventUpper = (event != null) ? event.toUpperCase() : '';
            Boolean shouldLog = LOGGABLE_EVENTS.contains(eventUpper);
            
            // Parse event timestamp
            Datetime eventDt;
            String eventDateStr = (String) payload.get('eventDate');
            if (String.isNotBlank(eventDateStr)) {
                eventDt = (Datetime) JSON.deserialize('"' + eventDateStr + '"', Datetime.class);
            }
            
            // Prepare audit log body (truncate if needed)
            String safeRawBody;
            try {
                safeRawBody = JSON.serializePretty(payload);
                if (safeRawBody != null && safeRawBody.length() > 32768) {
                    safeRawBody = safeRawBody.substring(0, 32768);
                }
            } catch (System.StringException se) {
                safeRawBody = 'Payload too large to serialize. Size: ' + bodySize + ' bytes';
            }
            
            // Extract agreement details
            Map<String, Object> agreement = (Map<String, Object>) payload.get('agreement');
            
            if (agreement != null) {
                String agreementId = (String) agreement.get('id');
                String agreementName = (String) agreement.get('name');
                String agreementStatus = (String) agreement.get('status');
                String senderEmail = (String) agreement.get('senderEmail');
                
                // Extract document ID
                String documentId;
                Map<String, Object> docsInfo = (Map<String, Object>) agreement.get('documentsInfo');
                if (docsInfo != null) {
                    List<Object> documents = (List<Object>) docsInfo.get('documents');
                    if (documents != null && !documents.isEmpty()) {
                        Map<String, Object> doc0 = (Map<String, Object>) documents[0];
                        documentId = (String) doc0.get('id');
                    }
                }
                
                Integer participantOrder = getParticipantOrder(agreement, participantUserId);
                
                // Find related Account
                List<Account> accList = [
                    SELECT Id, Name, OwnerId, RecordTypeId,
                           FA_Portal_Agreement_Status__c, FA_Portal_AgreementId__c
                    FROM Account
                    WHERE FA_Portal_AgreementId__c = :agreementId
                    LIMIT 1
                ];
                
                Account acc = accList.isEmpty() ? null : accList[0];
                
                // Terminal state guard - prevent infinite loop
                if (acc != null && TERMINAL_STATUSES.contains(acc.FA_Portal_Agreement_Status__c)) {
                    res.statusCode = 200;
                    return '{"success":true,"message":"Agreement already in terminal state: ' 
                           + acc.FA_Portal_Agreement_Status__c + '","skipped":true}';
                }
                
                String oldStatus = acc != null ? acc.FA_Portal_Agreement_Status__c : null;
                String newStatus = determineStatus(event, oldStatus, participantOrder);
                
                // Account not ready yet - schedule retry with backoff
                Boolean shouldRetry =
                    eventUpper == 'AGREEMENT_CREATED' ||
                    eventUpper == 'AGREEMENT_ACTION_REQUESTED' ||
                    eventUpper == 'AGREEMENT_ACTION_COMPLETED' ||
                    eventUpper == 'AGREEMENT_WORKFLOW_COMPLETED';

                if (acc == null) {
                    if (shouldRetry) {
                        scheduleRetryInMinutes(agreementId, event, participantOrder, 1, webhookId, 1);
                    }
                    res.statusCode = 200;
                    return '{"success":true,"message":"Account not found' + (shouldRetry ? ', retry scheduled' : ', ignored') + '"}';
                }
                
                // Create audit log
                if (shouldLog) {
                    logRec = new Portal_FA_Event_Log__c(
                        Agreement_Id__c         = agreementId,
                        Agreement_Name__c       = agreementName,
                        Agreement_Status__c     = agreementStatus,
                        Event__c                = event,
                        Event_Date__c           = eventDt,
                        Participant_Email__c    = participantEmail,
                        Webhook_Id__c           = webhookId,
                        Raw_Body__c             = safeRawBody,
                        Document_Id__c          = documentId,
                        Sender_Email__c         = senderEmail,
                        Account__c              = acc.Id,
                        New_Agreement_Status__c = newStatus,
                        Processing_Status__c    = 'Pending'
                    );
                    insert logRec;
                }
                
                // Update Account status and trigger PDF download
                if (oldStatus != newStatus) {
                    Account accToUpdate = new Account(
                        Id = acc.Id,
                        FA_Portal_Agreement_Status__c = newStatus
                    );
                    
                    if (newStatus == 'Client Signed') {
                        accToUpdate.FA_Payment_Status__c = 'Awaiting Trust Funding';
                    }
                    
                    update accToUpdate;
                    
                }     
                
                // Mark log as successful
                if (logRec != null) {
                    logRec.Processing_Status__c = 'Succeeded';
                    update logRec;
                }
            }
            
            res.statusCode = 200;
            return '{"success":true}';
            
        } catch (Exception e) {
            AdobeFaErrorLogUtil.logError(
                CLASS_NAME, 'handleWebhook', e, null, null,
                'Webhook body length: ' + (body != null ? body.length() : 0),
                AdobeFaErrorLogUtil.ErrorType.SYSTEM_ERROR
            );
            
            if (logRec != null && logRec.Id != null) {
                try {
                    logRec.Processing_Status__c = 'Failed';
                    logRec.Error_Message__c = e.getTypeName() +
                        ' (line ' + e.getLineNumber() + '): ' + e.getMessage();
                    update logRec;
                } catch (Exception logEx) {
                    // Silent failure
                }
            }
            
            res.statusCode = 200;
            return '{"success":false,"error":"' + String.escapeSingleQuotes(e.getMessage()) + '"}';
        }
    }
    
    /**
     * Determines which participant (by order) triggered the event.
     * Returns 1 for client, 2 for attorney, or null if not found.
     */
    private static Integer getParticipantOrder(Map<String, Object> agreement, String participantUserId) {
        if (String.isBlank(participantUserId)) return null;
        
        Map<String, Object> participantSetsInfo = (Map<String, Object>) agreement.get('participantSetsInfo');
        if (participantSetsInfo == null) return null;
        
        List<Object> participantSets = (List<Object>) participantSetsInfo.get('participantSets');
        if (participantSets == null) return null;
        
        for (Object psObj : participantSets) {
            Map<String, Object> ps = (Map<String, Object>) psObj;
            Integer order = (Integer) ps.get('order');
            List<Object> memberInfos = (List<Object>) ps.get('memberInfos');
            
            if (memberInfos != null) {
                for (Object memberObj : memberInfos) {
                    Map<String, Object> member = (Map<String, Object>) memberObj;
                    String userId = (String) member.get('userId');
                    if (userId == participantUserId) return order;
                }
            }
        }
        return null;
    }
    
    /**
     * Calculates new status based on event type and participant order.
     * 
     * Flow: Out for Signature → Client Signed → Client Signed-Waiting Atty → 
     *       Atty Signed → All Signed → FA Downloaded
     */
    private static String determineStatus(String event, String currentStatus, Integer participantOrder) {
        String e = event != null ? event.toUpperCase() : '';
        String cs = currentStatus;
        
        if (e == 'AGREEMENT_CREATED') return 'Out for Signature';
        
        if (e == 'AGREEMENT_ACTION_REQUESTED') {
            if (participantOrder == 1) return cs;
            if (participantOrder == 2) return 'Client Signed-Waiting Atty';
        }
        
        if (e == 'AGREEMENT_ACTION_COMPLETED') {
            if (participantOrder == 1) return 'Client Signed';
            if (participantOrder == 2) return 'Atty Signed';
        }
        
        if (e == 'AGREEMENT_WORKFLOW_COMPLETED') return 'All Signed';
        if (e == 'AGREEMENT_CANCELLED') return 'Cancelled';
        if (e == 'AGREEMENT_EXPIRED') return 'Expired';
        if (e == 'AGREEMENT_REJECTED') return 'Declined';
        
        return cs;
    }
    
    /**
     * Queueable job that retries webhook processing when Account not yet available.
     * Max 5 attempts before logging error and giving up.
     */
    global class RetryJob implements Queueable, Database.AllowsCallouts {
        private String docKey;
        private String eventName;
        private Integer participantOrder;
        private Integer attempt;
        private String webhookId;
        private final Integer MAX_ATTEMPTS = 10;
        
        public RetryJob(String docKey, String eventName, Integer participantOrder, 
                       Integer attempt, String webhookId) {
            this.docKey = docKey;
            this.eventName = eventName;
            this.participantOrder = participantOrder;
            this.attempt = attempt;
            this.webhookId = webhookId;
        }
        
        public void execute(QueueableContext qc) {
            if (retryJobExecuting) return;
            retryJobExecuting = true;
            
            try {
                executeInternal();
            } finally {
                retryJobExecuting = false;
            }
        }
        
        private void executeInternal() {
            List<Account> accList = [
                SELECT Id, Name, OwnerId, RecordTypeId,
                       FA_Portal_Agreement_Status__c, FA_Portal_AgreementId__c
                FROM Account
                WHERE FA_Portal_AgreementId__c = :docKey
                LIMIT 1
            ];
            
            if (!accList.isEmpty()) {
                Account acc = accList[0];
                
                // Terminal state guard
                if (TERMINAL_STATUSES.contains(acc.FA_Portal_Agreement_Status__c)) {
                    return;
                }
                
                String oldStatus = acc.FA_Portal_Agreement_Status__c;
                String newStatus = determineStatus(eventName, oldStatus, participantOrder);
                
                if (oldStatus != newStatus) {
                    Account accToUpdate = new Account(
                        Id = acc.Id,
                        FA_Portal_Agreement_Status__c = newStatus
                    );
                    
                    if (newStatus == 'Client Signed') {
                        accToUpdate.FA_Payment_Status__c = 'Awaiting Trust Funding';
                    }
                    
                    update accToUpdate;
                }
                
            } else {
                // Account not found - retry or give up (with backoff)
                if (attempt < MAX_ATTEMPTS) {
                    Integer nextAttempt = attempt + 1;

                    // Backoff minutes: 1,2,3,4,5 then cap at 5
                    Integer delayMins = Math.min(nextAttempt, 5);

                    scheduleRetryInMinutes(
                        docKey,
                        eventName,
                        participantOrder,
                        nextAttempt,
                        webhookId,
                        delayMins
                    );
                } else {
                    AdobeFaErrorLogUtil.logError(
                        CLASS_NAME, 'RetryJob.executeInternal', null, null, null,
                        'Account not found after ' + MAX_ATTEMPTS + ' attempts. ' +
                        'AgreementId=' + docKey + ', WebhookId=' + webhookId,
                        AdobeFaErrorLogUtil.ErrorType.API_ERROR
                    );
                }
            }
        }
    }
    
    public class WebhookException extends Exception {}
}