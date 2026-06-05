public class HubSpotAccountTriggerHandler {
    public static void handleAfterInsert(List<Account> newAccounts) {
        List<DelayedFormSubmission__c> submissions = new List<DelayedFormSubmission__c>();
        
        // List of RecordType DeveloperNames (API Names) to process
        Set<String> validRecordTypeNames = new Set<String>{
            'Web_PC', 
            'Potential_Client',
            'ZCC_Contact'
        };
        
        // Map to hold RecordType DeveloperName to Id mapping
        Map<String, Id> recordTypeNameToIdMap = new Map<String, Id>();
        
        // Populate the map with RecordType DeveloperName to Id mapping
        for (RecordType rt : [SELECT Id, DeveloperName FROM RecordType WHERE SObjectType = 'Account']) {
            if (validRecordTypeNames.contains(rt.DeveloperName)) {
                recordTypeNameToIdMap.put(rt.DeveloperName, rt.Id);
            }
        }
        
        for (Account acc : newAccounts) {
            System.debug('Account RecordTypeId: ' + acc.RecordTypeId);
            System.debug('Account PersonEmail: ' + acc.PersonEmail);
            if (acc.PersonEmail != null && recordTypeNameToIdMap.values().contains(acc.RecordTypeId)) {
                DelayedFormSubmission__c submission = new DelayedFormSubmission__c();
                submission.Email__c = acc.PersonEmail;
                submission.Status__c = 'Pending';
                submissions.add(submission);
            }
        }
        
        if (!submissions.isEmpty()) {
            try {
                insert submissions;
            } catch (DmlException e) {
                // Log the exception (consider using a custom logging framework)
                System.debug('Error inserting DelayedFormSubmission records: ' + e.getMessage());
            }
        }
    }
}