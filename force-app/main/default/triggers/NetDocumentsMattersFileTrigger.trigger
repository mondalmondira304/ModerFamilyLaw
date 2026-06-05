trigger NetDocumentsMattersFileTrigger on ContentDocumentLink (after insert) {
    try {
        // Retrieve trigger control from Custom Metadata
        ND_Trigger_Control__mdt triggerControl = ND_Trigger_Control__mdt.getInstance('NetDocuments_Trigger_Control');
        Boolean isTriggerActive = triggerControl != null ? triggerControl.Is_Active__c : true;

        if (!isTriggerActive) {
            System.debug('NetDocumentsMattersFileTrigger: Trigger is deactivated via Custom Metadata.');
            return; // Exit trigger if inactive
        }
        
        List<String> allowedObjects= new List<String> {'Additional_Asset__c', 'Additional_Debt__c', 'Bank_Account__c', 'Children__c', 
            'Credit_Card__c', 'Debt__c', 'Employment__c', 'Furniture_Personal_Property__c', 'Housing__c', 
            'Investment_Account__c', 'Life_Insurance__c', 'Matters__c', 'Medical_Providers__c', 'Other_Income__c', 'Other_Personal_Property__c',
            'Retirement_Account__c', 'Taxes__c', 'Utilites__c', 'Vehicle__c'};
        List<Id> mattersIds = new List<Id>();
        List<Id> contentDocumentLinkIds = new List<Id>();
        sObject sobj;
        String entityId;
        for (ContentDocumentLink link : Trigger.new) {
            // Check if the LinkedEntityId is of type Matters__c
             System.debug('NetDocumentsMattersFileTrigger: link.LinkedEntityId.getSObjectType().getDescribe().name): ' + link.LinkedEntityId.getSObjectType().getDescribe().name);
            if ( allowedObjects.contains(link.LinkedEntityId.getSObjectType().getDescribe().name)  ) {
                entityId=link.LinkedEntityId;
                if (link.LinkedEntityId.getSObjectType().getDescribe().name=='Matters__c'){
                    mattersIds.add(link.LinkedEntityId);
                }
                else if (link.LinkedEntityId.getSObjectType().getDescribe().name=='Credit_Card__c' || link.LinkedEntityId.getSObjectType().getDescribe().name=='Taxes__c' || link.LinkedEntityId.getSObjectType().getDescribe().name=='Children__c'){
                    sobj = Database.query('SELECT matter_id__c FROM '+link.LinkedEntityId.getSObjectType().getDescribe().name+' WHERE id = :entityId');
                    mattersIds.add((ID)sobj.get('matter_id__c'));
                }                                                
                else if (link.LinkedEntityId.getSObjectType().getDescribe().name=='Other_Income__c' || link.LinkedEntityId.getSObjectType().getDescribe().name=='Medical_Providers__c'){
                    sobj = Database.query('SELECT matter__c FROM '+link.LinkedEntityId.getSObjectType().getDescribe().name+' WHERE id = :entityId');
                    mattersIds.add((ID)sobj.get('matter__c'));                    
                }                 
                else if (link.LinkedEntityId.getSObjectType().getDescribe().name=='CUtilites__c'){
                    sobj = Database.query('SELECT matter_name__c FROM '+link.LinkedEntityId.getSObjectType().getDescribe().name+' WHERE id = :entityId');
                    mattersIds.add((ID)sobj.get('matter_name__c'));                    
                }                                 
                else {
                    sobj = Database.query('SELECT related_matter__c FROM '+link.LinkedEntityId.getSObjectType().getDescribe().name+' WHERE id = :entityId');
                    mattersIds.add((ID)sobj.get('related_matter__c'));   
                }
                contentDocumentLinkIds.add(link.ContentDocumentId);                
                System.debug('NetDocumentsMattersFileTrigger: Found linked ContentDocumentLink with Matter ID: ' + link.LinkedEntityId);
            }
        }

        // Only enqueue the job if there are valid Matter IDs and Content Document Link IDs
        if (!mattersIds.isEmpty() && !contentDocumentLinkIds.isEmpty()) {
            System.debug('NetDocumentsMattersFileTrigger: Enqueuing file upload job with Matters IDs: ' + mattersIds);
            System.enqueueJob(new NetDocumentsFileUploadQueueable(mattersIds, contentDocumentLinkIds));
        } else {
            System.debug('NetDocumentsMattersFileTrigger: No relevant ContentDocumentLink records found.');
        }
    } catch(exception e) {
        Utility.createErrorRecord(e.getMessage(), e.getStackTraceString(), e.getLineNumber(), e.getTypeName(), 'NetDocumentsMattersFileTrigger');                
    }   
}