public class HubSpotBatch implements Database.Batchable<SObject>, Database.AllowsCallouts {

    public Database.QueryLocator start(Database.BatchableContext bc) {
        System.debug('HubSpotBatch: Querying pending form submissions');
        return Database.getQueryLocator([
            SELECT Id, Email__c, Status__c, Error_Message__c FROM DelayedFormSubmission__c WHERE Status__c = 'Pending'
        ]);
    }

    public void execute(Database.BatchableContext bc, List<DelayedFormSubmission__c> scope) {
        System.debug('HubSpotBatch: Executing batch with scope size: ' + scope.size());
        
        List<DelayedFormSubmission__c> recordsToUpdate = new List<DelayedFormSubmission__c>();
        List<DelayedFormSubmission__c> recordsToDelete = new List<DelayedFormSubmission__c>();

        for (DelayedFormSubmission__c submission : scope) {
            System.debug('HubSpotBatch: Processing record Id: ' + submission.Id + ', Email: ' + submission.Email__c);
            try {
                HttpRequest req = new HttpRequest();
                Http http = new Http();
                String portalId = '44727065';
                String formGuid = 'fc28ad29-ecff-4603-8d4c-39cb00d6793e';
                String endpoint = 'https://api.hsforms.com/submissions/v3/integration/submit/' + portalId + '/' + formGuid;
                req.setEndpoint(endpoint);
                req.setMethod('POST');
                req.setHeader('Content-Type', 'application/json');

                // Construct JSON body
                String formData = '{"fields": [{"objectTypeId": "0-1", "name": "email", "value": "' + submission.Email__c + '"}]}';
                req.setBody(formData);

                System.debug('HubSpotBatch: Submitting to HubSpot: ' + formData);
                System.debug('HubSpotBatch: Endpoint: ' + endpoint);

                HttpResponse res = http.send(req);
                System.debug('HubSpotBatch: HubSpot response status: ' + res.getStatusCode());
                System.debug('HubSpotBatch: HubSpot response body: ' + res.getBody());

                if (res.getStatusCode() == 200) {
                    System.debug('HubSpotBatch: Form submission successful');
                    submission.Status__c = 'Processed';
                    recordsToDelete.add(submission); // Add to delete list only if processed successfully
                } else {
                    System.debug('HubSpotBatch: Form submission failed: ' + res.getBody());
                    submission.Status__c = 'Error';
                    submission.Error_Message__c = res.getBody();
                    recordsToUpdate.add(submission); // Update record with error status and message
                }
            } catch (Exception e) {
                System.debug('HubSpotBatch: An error occurred: ' + e.getMessage());
                submission.Status__c = 'Error';
                submission.Error_Message__c = e.getMessage();
                recordsToUpdate.add(submission); // Update record with error status and message
            }
        }
        
        // Update records with new statuses
        if (!recordsToUpdate.isEmpty()) {
            update recordsToUpdate;
        }

        // Delete only processed records
        if (!recordsToDelete.isEmpty()) {
            delete recordsToDelete;
            System.debug('HubSpotBatch: Deleted processed records');
        }
    }

    public void finish(Database.BatchableContext bc) {
        System.debug('HubSpotBatch: Batch job finished');
        // Implement any additional logic you need after the batch completes
    }
}