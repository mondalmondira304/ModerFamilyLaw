public without sharing class NetDocumentsMattersFileTriggerHandler {
    public class workspaceNotCreatedException extends Exception {}
    public class cabinetValueNullException extends Exception {}
    public class tooLargeException extends Exception {}

    @InvocableMethod(label='checkWorkspace' description='Checks if a NetDocuments workspace exists and creates the workspace if necessary.  Takes Account or Matter Id.' category='Matter')
    public static List<Boolean> checkWorkspace(List<Id> Ids){
        try {
            Map<Id,SObject>  objectMap;
            if (Ids[0].getSObjectType().getDescribe().getName()=='Matters__c'){ //length of array will always be 1
                objectMap = getMatters(Ids);
            } else if (Ids[0].getSObjectType().getDescribe().getName()=='Account'){
                objectMap = getAccounts(Ids);
            }
            ND_Trigger_Control__mdt triggerControl=getTriggerControl();
            return  new List<Boolean> {NetDocumentsFileAPI.checkWorkspace(objectMap.values()[0], triggerControl.Repository_Value__c, triggerControl.Cabinet_Value__c)};
        }   catch (Exception e) {
            Utility.createErrorRecord(e.getMessage(), e.getStackTraceString(), e.getLineNumber(), e.getTypeName(), 'NetDocumentsMattersFileTriggerHandler.checkWorkspace');
            return new List<Boolean> {false};
        }
    }
    private static Map<Id,Matters__c> getMatters(List<Id> Ids){
                return  new Map<Id, Matters__c> (//state needed to determine the workspace template
                    [SELECT Id, Name, Matter_ID_Client__c, Matter_ID_Matter__c, Case_Type__c, 
                    Petitioner__r.lastname, Petitioner__r.firstname,                
	                Client_Name__r.lastname, 	Client_Name__r.firstname,
                    jurisdiction__c, jurisdiction__r.state__c,                      
                    MFL_Office__c, MFL_office__r.state__c, 
                    Primary_Paralegal__r.Email, Primary_Attorney__r.Email, Primary_Paralegal__r.Id, Primary_Attorney__r.Id 
                    FROM Matters__c WHERE Id IN :Ids] 
                );  
    }
    private static Map<Id,Account> getAccounts(List<Id> Ids){
                return  new Map<Id, Account> ( //state needed to determine the workspace template
                    [SELECT Id, Name, firstname, lastname, Timesolv_Client_Number__c, Timesolv_Matter_Id__c, Type_of_Case_A__c,
                    Responsible_Office__c, State_A__c,
                    Responsible_Paralegal__r.Email, Responsible_Attorney__r.Email, Responsible_Paralegal__r.Id, Responsible_Attorney__r.Id 
                    FROM Account WHERE Id IN :Ids] 
                );  
    }    
    private static ND_Trigger_Control__mdt getTriggerControl(){
            ND_Trigger_Control__mdt triggerControl = ND_Trigger_Control__mdt.getInstance('NetDocuments_Trigger_Control');
            Boolean isTriggerActive = (triggerControl != null) ? triggerControl.Is_Active__c : true;
            if (!isTriggerActive) {
                cabinetValueNullException ex = new cabinetValueNullException('NetDocumentsMattersFileTriggerHandler: Trigger is deactivated via Custom Metadata.  Contact IT Support.');                                
                throw ex;                 
            }
            String repositoryValue = (triggerControl != null && triggerControl.Repository_Value__c != null)
                                    ? triggerControl.Repository_Value__c 
                                    : '';
            if (String.isBlank(repositoryValue)) {
                System.debug('NetDocumentsMattersFileTriggerHandler: Repository Value is not configured in ND_Trigger_Control__mdt.');
                cabinetValueNullException ex = new cabinetValueNullException('Not able to find a valid NetDocuments repository value.  Contact IT Support.');                                
                throw ex;  //exception handled by calling method
            }
            String cabinetValue =   (triggerControl != null && triggerControl.Cabinet_Value__c != null)
                                    ? triggerControl.Cabinet_Value__c 
                                    : '';
            if (String.isBlank(cabinetValue)) {  //special cabinet value just for uploads
                System.debug('NetDocumentsMattersFileTriggerHandler: Cabinet Value  is not configured in ND_Trigger_Control__mdt.');
                cabinetValueNullException ex = new cabinetValueNullException('Not able to find a valid NetDocuments cabinet value.  Contact IT Support.');                                
                throw ex;  //exception handled by calling method                
            }  
            return triggerControl;
    }
    public static void handleFileUpload(List<Id> mattersIds, List<Id> contentDocumentLinkIds) { //file uploads only happen from matters
        String combinedMatterId;  // all these objects need to be available in the exception block
        String fileNameWithExtension;
        Matters__c matter;
        try {
            System.debug('NetDocumentsMattersFileTriggerHandler: Starting handleFileUpload method');
            // Retrieve trigger control from Custom Metadata
            ND_Trigger_Control__mdt triggerControl=getTriggerControl();  //validates that repository value and cabinet value are populated
            Map<Id, Matters__c> mattersMap = getMatters(mattersIds);  //file uploads do not happen in batches...mattersIds will just be one record
            matter = mattersMap.values()[0];  
            combinedMatterId = mattersMap.values()[0].Matter_ID_Client__c + ' - ' + mattersMap.values()[0].Matter_ID_Matter__c;                         
            // Retrieve ContentDocumentLink
            List<ContentDocumentLink> docLinks = [
                SELECT Id, ContentDocumentId, LinkedEntityId
                FROM ContentDocumentLink
                WHERE ContentDocumentId IN :contentDocumentLinkIds
            ];           
            Map<Id, ContentDocumentLink> contentDocumentLinkMap = new Map<Id, ContentDocumentLink>();
            List<Id> contentDocumentIds = new List<Id>();
            for (ContentDocumentLink cdl : docLinks) {
                contentDocumentLinkMap.put(cdl.ContentDocumentId, cdl);
                contentDocumentIds.add(cdl.ContentDocumentId);
            }
            // Retrieve ContentDocument
            List<ContentDocument> docList = [
                SELECT Id, Title, FileType, LatestPublishedVersionId
                FROM ContentDocument
                WHERE Id IN :contentDocumentIds
            ];
            Map<Id, ContentDocument> contentDocumentMap = new Map<Id, ContentDocument>();
            List<Id> contentVersionIds = new List<Id>();            
            for (ContentDocument cd : docList) {
                contentVersionIds.add(cd.LatestPublishedVersionId);
                contentDocumentMap.put(cd.LatestPublishedVersionId, cd);
            }
            // Retrieve ContentVersion
            // check the file size here and throw an error if beyond the limit                                 
            List<ContentVersion> contentVersions = [ SELECT Id, ContentSize FROM ContentVersion WHERE Id IN :contentVersionIds];  //single files are processed
            ContentDocument doc = contentDocumentMap.get(contentVersions[0].Id); 
            fileNameWithExtension = doc.Title + '.' + doc.FileType;              
            if (contentVersions[0].ContentSize>=15824224){
                tooLargeException ex = new tooLargeException('The file is too large to upload automatically.  Please upload manually to NetDocuments:  '+fileNameWithExtension);   
                throw ex;                                                 
            }
            contentVersions = [ SELECT Id, VersionData, ContentSize FROM ContentVersion WHERE Id IN :contentVersionIds];  //at this point we know if the file size can be handled without a heap size exception   
            // Perform uploads
            for (ContentVersion cv : contentVersions) {
                ContentDocumentLink cdl = contentDocumentLinkMap.get(doc.Id);             
                if (doc != null && cdl != null && !doc.FileType.equalsIgnoreCase('snote')) {
  
                    if (matter != null) {
                        // Combine matter ID parts  TODO checkWorkspace parameters have changed                   
                        Boolean workspaceExists= NetDocumentsFileAPI.checkWorkspace (matter, triggerControl.Repository_Value__c, triggerControl.Cabinet_Value__c);
                        if (!workspaceExists) {
                            System.debug('NetDocumentsMattersFileTriggerHandler: workspace does not exist for ' + matter.Name);     
                            workspaceNotCreatedException ex = new workspaceNotCreatedException('Not able to create the workspace for this client and matter:  '+combinedMatterId+'.  '+'Contact Salesforce Support.');                                
                            throw ex;                 
                        }
                        // Synchronous upload call
                        Boolean uploadSuccess = NetDocumentsFileAPI.uploadFile(
                            matter, //added at the last minute for exception tracking
                            fileNameWithExtension,
                            cv.VersionData,
                            matter.Matter_ID_Matter__c,
                            matter.Matter_ID_Client__c,
                            triggerControl.Cabinet_Value__c
                        );                        
                        if (uploadSuccess) {
                            // Send the email notification
                            invokeEmailFlow(matter.Id, matter.Name, combinedMatterId, fileNameWithExtension, true);
                            //createTaskToTrackUpload(matter.Id, combinedMatterId, fileNameWithExtension, true, '');
                        } else {
                            System.debug('NetDocumentsMattersFileTriggerHandler: Upload failed for Matter ' + matter.Name);
                        }
                    }
                }
            }
        } catch(exception e) {
            Utility.createErrorRecord(e.getMessage(), e.getStackTraceString(), e.getLineNumber(), e.getTypeName(), 'NetDocumentsMattersFileTriggerHandler.handleFileUpload');     
            invokeEmailFlow(matter.Id, matter.Name, combinedMatterId, fileNameWithExtension, false);  //TODO   send out an error notification
            createTaskToTrackUpload(matter.Id, combinedMatterId, fileNameWithExtension, false, e.getMessage());                                
        }
    }
    @future
    public static void createTaskToTrackUpload(String matterId, String combinedMatterId, String fileNameWithExtension, Boolean successful, String errorMessage){
        try {
            Matters__c matterRecord = [
                SELECT Id, Name, Primary_Paralegal__r.Email, Primary_Attorney__r.Email, Primary_Paralegal__r.Id, Primary_Attorney__r.Id FROM Matters__c
                WHERE Id = :matterId
                LIMIT 1
            ];
            Task inserted = new Task();            
            inserted.WhatId=matterId;
            if (successful){
                inserted.Subject='Matter Update: File Uploaded for ' +combinedMatterId+'  '+fileNameWithExtension;
            } else { // there was an error
                inserted.Subject='Matter Update: File Upload Failed for ' +combinedMatterId+'  '+fileNameWithExtension;
                inserted.Description='The file could not be uploaded due to an error:  '+errorMessage;
                inserted.Priority='High';
            }
            if (!String.isEmpty(matterRecord.Primary_Attorney__r.Id) ) {
                inserted.OwnerId=matterRecord.Primary_Attorney__r.Id;
            }   else if (!String.isEmpty(matterRecord.Primary_Paralegal__r.Id)) {
                inserted.OwnerId=matterRecord.Primary_Paralegal__r.Id;
            }
            inserted.Status='Open';
            inserted.ActivityDate=system.today();
            insert inserted;  
        }   catch (Exception e) {
            Utility.createErrorRecord(e.getMessage(), e.getStackTraceString(), e.getLineNumber(), e.getTypeName(), 'NetDocumentsMattersFileTriggerHandler.createTaskToTrackUser');
        }
    }
    @TestVisible
    private static void invokeEmailFlow(Id matterId, String matterName, String concatenatedMatterId, String fileName, Boolean successful) {
        try {
            System.debug('Starting invokeEmailFlow method...');
            Matters__c matterRecord = [SELECT Id, Name, Primary_Paralegal__r.Email, Primary_Attorney__r.Email FROM Matters__c WHERE Id = :matterId];
            System.debug('matterRecord: ' + matterRecord);
            System.debug('matterRecord emails: ' + matterRecord.Primary_Paralegal__r.Email + matterRecord.Primary_Attorney__r.Email );                
            List<String> toAddresses = new List<String>();
            if (!String.isEmpty(matterRecord.Primary_Paralegal__r.Email)) {
                toAddresses.add(matterRecord.Primary_Paralegal__r.Email);
            }
            if (!String.isEmpty(matterRecord.Primary_Attorney__r.Email)) {
                toAddresses.add(matterRecord.Primary_Attorney__r.Email);
            }
            if (toAddresses.isEmpty()) {
                System.debug('No valid email addresses for matter: ' + matterName);
                return;
            }
            // Build the URL using the new method:
            String matterURL = System.Url.getOrgDomainUrl().toExternalForm()+ '/lightning/r/Matters__c/' + matterId + '/view';
            Messaging.SingleEmailMessage email = new Messaging.SingleEmailMessage();
            email.setToAddresses(toAddresses);
            email.setSenderDisplayName('Salesforce Notification');
            String emailBody = 
                '<li><b>Matter Name:</b> ' + matterName + '</li>' +
                '<li><b>Matter Number:</b> ' + concatenatedMatterId + '</li>' +
                '<li><b>File Name:</b> ' + fileName + '</li>' +
                '</ul>' +
                '<p>You can view the matter at:</p>' +
                '<p><a href="' + matterURL + '">' + matterURL + '</a></p>' +
                '<p>Thank you,<br/>Salesforce Team</p>';            
            if (successful){
                email.setSubject('Matter Update: File Uploaded for ' + matterName);
                emailBody = 
                    '<p>Hello,</p>' +
                    '<p>A new document has been uploaded to the Matter and to NetDocuments.  Please review:</p>' +
                    '<ul>' + emailBody;

            } else {
                email.setSubject('Matter Update: File Upload Failed for ' + matterName);                     
                emailBody = 
                    '<p>Hello,</p>' +
                    '<p>A new document has been uploaded to the Matter but was not uploaded to NetDocuments. Please attempt to upload it to NetDocuments manually.</p>' +
                    '<ul>' + emailBody;                
            }
            email.setHtmlBody(emailBody);
            Messaging.sendEmail(new Messaging.SingleEmailMessage[] { email });
            System.debug('Email sent to: ' + toAddresses);
        } catch (Exception e) {
            System.debug('Error invoking email flow: ' + e.getMessage());
            Utility.createErrorRecord(e.getMessage(), e.getStackTraceString(), e.getLineNumber(), e.getTypeName(), 'NetDocumentsMattersFileTriggerHandler.invokeEmailFlow');                 
        }
    }
}