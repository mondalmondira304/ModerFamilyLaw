public without sharing class NetDocumentsFileAPI {
    /**
     * Uploads a single file to NetDocuments synchronously using a Named Credential.
     *
     * @param fileName       The file name + extension (e.g. "Example.pdf").
     * @param fileData       The file data in Blob form.
     * @param matterID       The Matter ID (from Matter__c) for NetDocuments.
     * @param clientID       The Client ID (from Matter__c) for NetDocuments.
     * @param cabinetValue   The NetDocuments cabinet identifier (e.g. "NG-UBO32328").
     * @return               True if upload succeeded (statusCode == 200), else false.
     */    
    public class netDocsClient{ //JSON used to create a client
        public String description;	//Testing Client 2026
        public String key;	//9998T
        public netDocsClient(Matters__c matter){
            this.description=matter.Client_Name__r.lastname+', '+matter.Client_Name__r.firstname;                   
            this.key=matter.Matter_ID_Client__c;
        }
        public netDocsClient(Account acct){
            this.description=acct.lastname+', '+acct.firstname;                   
            this.key=acct.Timesolv_Client_Number__c;
        }        
    }
    public class netDocsMatter{  //JSON used to create a matter
        public String parent;	//9999T        
        public String key;	//005
        public String description;	//DOM
        public boolean hold;
        public String defaulting;	//COL
        public netDocsMatter(Matters__c matter){
            this.parent=matter.Matter_ID_Client__c;            
            this.key=matter.Matter_ID_Matter__c;
            this.description=matter.Case_Type__c;
            this.hold=false;
            this.defaulting=getDefaultingValue(matter);              
        }
        public netDocsMatter(Account acct){
            this.parent=acct.Timesolv_Client_Number__c;            
            this.key=acct.Timesolv_Matter_Id__c;  //TODO************--can't be used as this is an internal number
            this.description=acct.Type_of_Case_A__c;
            this.hold=false;
            this.defaulting=getDefaultingValue(acct);              
        }
        public netDocsMatter()        {
            this.parent=null;            
            this.key=null;
            this.description=null;
            this.hold=null;
            this.defaulting=null;                
        }
    }
    public static Boolean checkWorkspace (SObject accountOrMatter, String repositoryValue, String cabinetValue){ //updated to be polymorphic
        try {
            netDocsMatter matterInstance;
            netDocsClient clientInstance;
            if (accountOrMatter instanceof Account) {
                Account acct = (Account)accountOrMatter;
                matterInstance= new netDocsMatter(acct);
                clientInstance= new netDocsClient(acct);
            } else if (accountOrMatter instanceof Matters__c){
                Matters__c matter = (Matters__c)accountOrMatter;
                matterInstance= new netDocsMatter(matter);  
                clientInstance= new netDocsClient(matter);                                   
            }
            if (checkClientId(clientInstance, repositoryValue)){ //creates the client if necessary
                if (checkMatterId(matterInstance, repositoryValue)) {  //creates the matter if necessary
                    return getWorkspaceInfo(matterInstance, cabinetValue);  //creates the workspace folders in NetDocuments    
                }
            } 
            return false;  //error condition
        }  catch (Exception e){
            Utility.createErrorRecord(e.getMessage(), e.getStackTraceString(), e.getLineNumber(), e.getTypeName(), 'NetDocumentsFileAPI.checkWorkspace');
            throw e;  //rethrow exception
        }
    }    
    public static String getDefaultingValue(Matters__c matter){
        //return the defaulting value that will generate the folder structure based upon the state
        if (matter.jurisdiction__c!=null && matter.jurisdiction__r.state__c!=null)  {
            return matter.jurisdiction__r.state__c.toUpperCase().subString(0,3);
        } else if (matter.MFL_Office__c!=null && matter.MFL_Office__r.state__c!=null){
            return matter.MFL_Office__r.state__c.toUpperCase().subString(0,3);
        } else { 
            return null; 
        }
    }
    public static String getDefaultingValue(Account acct){
        //return the defaulting value that will generate the folder structure based upon the state
        if (acct.State_A__c!=null)  {
            return acct.State_A__c.toUpperCase().subString(0,3);
        }         
        else { 
            return null; 
        }
    }    
    public static Boolean getWorkspaceInfo( netDocsMatter matterInstance, String cabinetValue){
        HttpRequest req = new HttpRequest();
        req.setEndpoint('callout:NetdocumentsNC/v1/workspace/'+cabinetValue+'/'+matterInstance.parent+'/'+matterInstance.key+'/info');
        req.setMethod('GET');        
        // Named Credential injects Authorization automatically
        req.setHeader('Accept', 'application/json');
        req.setHeader('User-Agent', 'NDPostmanAPIs');
        req.setHeader('Content-Type', 'application/json');
        req.setTimeout(60000); //because it takes a long time to populate the workspace with folders
        System.debug('NetDocumentsFileAPI.getWorkspaceInfo: req: ' + req);            
        try {
            Http http = new Http();
            HttpResponse res = http.send(req);            
            System.debug('NetDocumentsFileAPI.getWorkspaceInfo: Response status code: ' + res.getStatusCode());              
            return (res.getStatusCode() == 200);
        } catch (Exception e) {
            Utility.createErrorRecord(e.getMessage(), e.getStackTraceString(), e.getLineNumber(), e.getTypeName(), 'NetDocumentsFileAPI.getWorkspaceInfo');
            throw e;  //rethrow exception
        }
    }
    public static Boolean checkClientId( netDocsClient clientInstance, String repositoryValue){
        HttpRequest req = new HttpRequest();
        req.setEndpoint('callout:NetdocumentsNC/v1/attributes/'+repositoryValue+'/1/'+clientInstance.key);
        req.setMethod('GET');        
        // Named Credential injects Authorization automatically
        req.setHeader('Accept', 'application/json');
        req.setHeader('User-Agent', 'NDPostmanAPIs');
        req.setHeader('Content-Type', 'application/json');
        System.debug('NetDocumentsFileAPI.checkClientId: req: ' + req);            
        try {
            Http http = new Http();
            HttpResponse res = http.send(req);            
            System.debug('NetDocumentsFileAPI.checkClientId: Response status code: ' + res.getStatusCode());    
            if (res.getStatusCode()==200)   {
                return true;
            } else { //create client
                //netDocsClient body=new netDocsClient(matter);
                req.setMethod('PUT');
                req.setBody(JSON.serialize(clientInstance));                 
                res = http.send(req);                
                System.debug('NetDocumentsFileAPI.checkClientId creation of client: Response status code: ' + res.getStatusCode());                   
                return (res.getStatusCode() == 200);
            }
        } catch (Exception e) {
            Utility.createErrorRecord(e.getMessage(), e.getStackTraceString(), e.getLineNumber(), e.getTypeName(), 'NetDocumentsFileAPI.checkClientId');
            throw e;  //rethrow exception
        }
    }
    public static Boolean checkMatterId( netDocsMatter matterInstance, String repositoryValue){
        Boolean createUpdateMatter=false;  
        HttpRequest req = new HttpRequest();
        req.setEndpoint('callout:NetdocumentsNC/v1/attributes/'+repositoryValue+'/2/'+matterInstance.parent+'/'+matterInstance.key);
        req.setMethod('GET');        
        // Named Credential injects Authorization automatically
        req.setHeader('Accept', 'application/json');
        req.setHeader('User-Agent', 'NDPostmanAPIs');
        req.setHeader('Content-Type', 'application/json');        
        System.debug('NetDocumentsFileAPI.checkMatterId: req: ' + req);          
        try {
            Http http = new Http();
            HttpResponse res = http.send(req);            
            System.debug('NetDocumentsFileAPI.checkMatterId: Response status code: ' + res.getStatusCode());            
            if (res.getStatusCode()==200)   {           
                NetDocsMatter currentMatter  = (NetDocsMatter) JSON.deserialize(res.getBody(), NetDocsMatter.class);                
                if (currentMatter.description==matterInstance.description){
                    return true; // matter description/type has not changed
                } else { 
                    createUpdateMatter=true; 
                }
            } else { //create/update matter as no matter was found
                createUpdateMatter=true;
            }
            if (createUpdateMatter){
                //netDocsMatter body=new netDocsMatter(matter);
                req.setMethod('PUT');
                req.setBody(JSON.serialize(matterInstance));                 
                res = http.send(req);                
                System.debug('NetDocumentsFileAPI.checkMatterId creation of matter: Response status code: ' + res.getStatusCode());                   
                return (res.getStatusCode() == 200);  // even though the matter was created, it takes several seconds for it to be available
            }
            return true;
        } catch (Exception e) {
            Utility.createErrorRecord(e.getMessage(), e.getStackTraceString(), e.getLineNumber(), e.getTypeName(), 'NetDocumentsFileAPI.checkMatterId');
            throw e;  //rethrow exception
        }
    }    
    public static Boolean uploadFile(
        Matters__c matter, //added later for exception tracking purposes
        String fileName, 
        Blob fileData, 
        String matterID, 
        String clientID,
        String cabinetValue
    ) {
        try {
            HttpRequest req = new HttpRequest();
            req.setEndpoint('callout:NetdocumentsNC/v1/Document');
            req.setMethod('POST');
            
            // Named Credential injects Authorization automatically
            req.setHeader('Accept', 'application/json');
            req.setHeader('User-Agent', 'NDPostmanAPIs');

            // Generate a unique boundary
            String boundary = '--------------------------' + String.valueOf(DateTime.now().getTime());
            req.setHeader('Content-Type', 'multipart/form-data; boundary=' + boundary);

            // Build the multipart form-data body
            String bodyPrefix = '--' + boundary + '\r\n' +
                'Content-Disposition: form-data; name="action"\r\n\r\n' +
                'upload\r\n' +
                '--' + boundary + '\r\n' +
                'Content-Disposition: form-data; name="file"; filename="' + fileName + '"\r\n' +
                'Content-Type: text/plain\r\n' +
                'Content-Transfer-Encoding: base64\r\n\r\n';

            String fileDataBase64 = EncodingUtil.base64Encode(fileData);
            //'All Information from Client' specified if the user profile is like 'Customer Community'
            String netDocsProfile;
            String profileId=UserInfo.getProfileId();
            if (fileName.toLowerCase().startsWith('fee agreement')){  //this condition takes precedence--Fee Agreements always go into this view/folder
                netDocsProfile=  '[{"id":1,"value":"' + clientID + '"},{"id":2,"value":"' + matterID + '"},{"id":3,"value":"Intake Sheet and Signed Fee Agreement"}]\r\n';
            } else if ([Select Name from Profile Where Id =:profileId Limit 1][0].name.contains('Customer Community')){
                netDocsProfile=  '[{"id":1,"value":"' + clientID + '"},{"id":2,"value":"' + matterID + '"},{"id":3,"value":"All Information from Client"}]\r\n';                
            }   else {
                netDocsProfile= '[{"id":1,"value":"' + clientID + '"},{"id":2,"value":"' + matterID + '"}]\r\n';
            }
            String bodySuffix = '\r\n--' + boundary + '\r\n' +
                'Content-Disposition: form-data; name="profile"\r\n\r\n' +
                netDocsProfile +
                '--' + boundary + '\r\n' +
                'Content-Disposition: form-data; name="cabinet"\r\n\r\n' +
                cabinetValue + '\r\n' +
                '--' + boundary + '\r\n' +
                'Content-Disposition: form-data; name="return"\r\n\r\n' +
                'full\r\n' +
                '--' + boundary + '--';

            String fullBodyString = bodyPrefix + fileDataBase64 + bodySuffix;
            req.setBodyAsBlob(Blob.valueOf(fullBodyString));
            Http http = new Http();
            HttpResponse res = http.send(req);            
            System.debug('NetDocumentsFileAPI: Response status code: ' + res.getStatusCode());
            System.debug('NetDocumentsFileAPI: Response body: ' + res.getBody());        
            return (res.getStatusCode() == 200);
        } catch (Exception e) {
            if (e.getMessage().contains('String length exceeds maximum')){
                String combinedMatterId=clientID+' - '+matterId;                
                createTaskToTrackError(matter, combinedMatterId, fileName, 'The file is too large to upload automatically.  Please upload manually to NetDocuments:  '+fileName);
            }
            Utility.createErrorRecord(e.getMessage(), e.getStackTraceString(), e.getLineNumber(), e.getTypeName(), 'NetDocumentsFileAPI.uploadFile');
            return false;
        }            
    }
    public static void createTaskToTrackError(Matters__c matter,String combinedMatterId, String fileNameWithExtension, String errorMessage)    {
        Task inserted = new Task();            
        inserted.WhatId=matter.Id;
        inserted.Subject='Matter Update: File Upload Failed for ' +combinedMatterId+'  '+fileNameWithExtension;
        inserted.Description=errorMessage;
        inserted.Priority='High';
        if (!String.isEmpty(matter.Primary_Attorney__r.Id) ) {
            inserted.OwnerId=matter.Primary_Attorney__r.Id;
        }   else if (!String.isEmpty(matter.Primary_Paralegal__r.Id)) {
            inserted.OwnerId=matter.Primary_Paralegal__r.Id;
        }
        inserted.Status='Open';
        inserted.ActivityDate=system.today();
        insert inserted; 
    }
}