/**
 * @description Queueable job to associate a Contact with a Client and Project in TimeSolv.
 *              
 * @author Sanders
 * @date 2025-04-18
 */
public class timesolvIntegrationContactAssociation implements Queueable, Database.AllowsCallouts {
    
    
    /** Allows tests to override our base-URL without touching MDT */
    @TestVisible
    private static String initBaseUrl() {
        if (Test.isRunningTest()) {
            return 'https://test.salesforcelocal';
        }
        TimeSolv_Integration_Configuration__mdt ep = [
            SELECT Endpoint_URL__c 
              FROM TimeSolv_Integration_Configuration__mdt 
             WHERE Label = 'Production'
             LIMIT 1
        ];
        return (ep != null ? ep.Endpoint_URL__c : '');
    }

    /** Prevents chaining the TrustAccount job in test runs */
    @TestVisible
    private static Boolean skipChainedTrustCall = false;


    // ─────────────────────────────────────────────────────────────────
    // 2) YOUR CONSTANTS — no change except calling our new initBaseUrl()
    // ─────────────────────────────────────────────────────────────────

    private static final String BASE_URL           = initBaseUrl();
    private static final String ASSOCIATE_ENDPOINT = BASE_URL + '/contactAssociations';

    
    
    
    
    private Id    accountId;
    private String clientId;
    private String contactId;
    private String bearerToken;
    private String projectId;

   

    public timesolvIntegrationContactAssociation(
        Id accountId,
        String clientId,
        String contactId,
        String bearerToken,
        String projectId
    ) {
        this.accountId   = accountId;
        this.clientId    = clientId;
        this.contactId   = contactId;
        this.bearerToken = bearerToken;
        this.projectId   = projectId;
    }

    public void execute(QueueableContext qc) {
        // Build callout
        AssociationWrapper wrapper = new AssociationWrapper(
            contactId,
            clientId,
            true,
            'Main',
            projectId
        );
        HttpRequest req = new HttpRequest();
        req.setEndpoint(ASSOCIATE_ENDPOINT);
        req.setMethod('POST');
        req.setHeader('Content-Type','application/json');
        req.setHeader('Authorization','Bearer ' + bearerToken);
        req.setBody(JSON.serialize(new List<AssociationWrapper>{ wrapper }));

        HttpResponse res;
        try {
            res = new Http().send(req);
        } catch (Exception e) {
            TimeSolvIntegrationLogUtil.logError(
                accountId,
                TimeSolvIntegrationLogUtil.INTEGRATION_TYPE_ASSOCIATION,
                'Callout exception: ' + e.getMessage(),
                e
            );
            updateStatus('Error', 'Callout exception');
            return;
        }

        Integer code = res.getStatusCode();
        if (code == 200 || code == 201) {
            updateStatus('Success', 'Contact associated');
            // Enqueue Trust Account creation
            if (projectId != null && !skipChainedTrustCall&& Limits.getQueueableJobs() < Limits.getLimitQueueableJobs()) {
                System.enqueueJob(
                    new timesolvIntegrationTrustAccountCall(projectId, bearerToken, accountId)
                );
                TimeSolvIntegrationStatusTask.updateIntegrationStatusTask(
                    new Account(Id = accountId),
                    'Trust Account Creation',
                    'Queued',
                    'Trust Account creation queued',
                    null
                );
            }
        } else {
            TimeSolvIntegrationLogUtil.logError(
                accountId,
                TimeSolvIntegrationLogUtil.INTEGRATION_TYPE_ASSOCIATION,
                'API error (' + code + '): ' + res.getBody(),
                null
            );
            updateStatus('Error', 'API error: ' + code);
        }
    }

   

    private void updateStatus(String status, String message) {
        TimeSolvIntegrationStatusTask.updateIntegrationStatusTask(
            new Account(Id = accountId),
            'Contact Association',
            status,
            message,
            null
        );
    }

    public class AssociationWrapper {
        public String  ContactId          { get; set; }
        public String  ClientId           { get; set; }
        public Boolean HasPortalAccess    { get; set; }
        public String  ContactType        { get; set; }
        public String  ProjectId          { get; set; }

        public AssociationWrapper(
            String contactId,
            String clientId,
            Boolean hasPortal,
            String contactType,
            String projectId
        ) {
            this.ContactId       = contactId;
            this.ClientId        = clientId;
            this.HasPortalAccess = hasPortal;
            this.ContactType     = contactType;
            this.ProjectId       = projectId;
        }
    }
}