public class FileUploadController {
    @AuraEnabled
    public static string getVersionDataUrl(Id recordId) {
        try {
            List<ContentVersion> contentList = [SELECT Id, Title, VersionDataUrl, ContentDocumentId, FileExtension, createddate FROM ContentVersion WHERE Id =:recordId order by createddate desc];
            return contentList[0].VersionDataUrl;           
        } catch (Exception e) {
            Utility.createErrorRecord(e.getMessage(), e.getStackTraceString(), e.getLineNumber(), e.getTypeName(), 'FileUploadController.getFileDetails');     
            throw new AuraHandledException(e.getMessage());
        }
    } 
    @AuraEnabled
    public static void deleteFileAndDocument(String contentVersionId) {
        try {
            ContentVersion cv = [SELECT Id, ContentDocumentId FROM ContentVersion WHERE Id = :contentVersionId LIMIT 1];
            delete [SELECT Id FROM ContentDocument WHERE Id = :cv.ContentDocumentId];
        } catch (Exception e) {
            Utility.createErrorRecord(e.getMessage(), e.getStackTraceString(), e.getLineNumber(), e.getTypeName(), 'MatterController.getMatterDetailsForPortalUser');               
            //throw new AuraHandledException('Error deleting file and document: ' + e.getMessage());
        }
    }
    @AuraEnabled
    public static List<ContentVersion> getAssociatedFiles(Id recordId) {
    try{
        if (recordId==null){
            return null;
        }
        //  Only allow the Portal user to see the list of files that they created.
        List<ContentDocumentLink> links = [ SELECT Id, LinkedEntityId, ContentDocument.Title,  contentdocument.CreatedDate FROM ContentDocumentLink 
            WHERE LinkedEntityId = :recordId and contentdocument.createdbyid=:UserInfo.getUserId() order by contentdocument.CreatedDate desc];
        if (links.isEmpty()) {
            return null;
        }
        Set<Id> contentIds = new Set<Id>();
        for (ContentDocumentLink link : links) {
            contentIds.add(link.ContentDocumentId);
        }
        return [    SELECT Id, Title, createddate FROM ContentVersion WHERE ContentDocumentId IN :contentIds AND IsLatest = TRUE ORDER BY CreatedDate desc   ];
    }
    catch(exception e) {
        Utility.createErrorRecord(e.getMessage(), e.getStackTraceString(), e.getLineNumber(), e.getTypeName(), 'MatterController.getMatterDetailsForPortalUser');                
        throw new AuraHandledException('Error getting matter details: ' + e.getMessage());
        } 
    }
    /* Everything below can be deleted when the new File Upload component is fully implemented */

    @AuraEnabled
    public static String uploadFile(String fileName, String base64Data, Id parentId) {
        try {
            // Create a new ContentVersion object
            ContentVersion contentVersion = new ContentVersion();
            contentVersion.Title = fileName;
            contentVersion.PathOnClient = fileName;
            contentVersion.VersionData = EncodingUtil.base64Decode(base64Data);
            contentVersion.FirstPublishLocationId = parentId;
            contentVersion.IsMajorVersion = true;
            insert contentVersion;
            // Return the Id of the inserted ContentVersion
            return contentVersion.Id;
        } catch (Exception e) {
            //Utility.createErrorRecord(e.getMessage(), e.getStackTraceString(), e.getLineNumber(), e.getTypeName(), 'FileUploadController.uploadFile');
            throw new AuraHandledException('File upload failed: ' + e.getMessage());
        }
    }
    @AuraEnabled
    public static void uploadFile1(String parentId, String fileName, String base64Data) {
        try {
            if (String.isNotBlank(parentId) && String.isNotBlank(base64Data)) {
                ContentVersion cv = new ContentVersion();
                cv.Title = fileName;
                cv.PathOnClient = fileName;
                cv.VersionData = EncodingUtil.base64Decode(base64Data);
                insert cv;
                // Get ContentDocumentId
                cv = [SELECT Id, ContentDocumentId FROM ContentVersion WHERE Id = :cv.Id LIMIT 1];
                // Link file to Account
                ContentDocumentLink cdl = new ContentDocumentLink();
                cdl.ContentDocumentId = cv.ContentDocumentId;
                cdl.LinkedEntityId = parentId;
                cdl.ShareType = 'V'; // View permission
                insert cdl;
            }
        } catch (Exception e) {
            //Utility.createErrorRecord(e.getMessage(), e.getStackTraceString(), e.getLineNumber(), e.getTypeName(), 'FileUploadController.uploadFile1');
            throw new AuraHandledException(e.getMessage());
        }
    }
    @AuraEnabled
    public static String saveFile(Id recordId, String fileName, String base64Data) {
        try {
            ContentVersion contentVersion = new ContentVersion();
            contentVersion.Title = fileName;
            contentVersion.PathOnClient = fileName;
            contentVersion.VersionData = EncodingUtil.base64Decode(base64Data);
            contentVersion.Origin = 'H';
            contentVersion.FirstPublishLocationId = recordId;
            contentVersion.ContentLocation = 'S';
            Database.insert(contentVersion,false, AccessLevel.SYSTEM_MODE );
            return contentVersion.Id;           
        } catch (Exception e) {
            //Utility.createErrorRecord(e.getMessage(), e.getStackTraceString(), e.getLineNumber(), e.getTypeName(), 'FileUploadController.saveFile');            
            throw new AuraHandledException(e.getMessage());
        }
    }
    @AuraEnabled
    public static string getFileDetails(Id recordId) {
        try {
            List<ContentVersion> contentList = [SELECT Id, VersionDataUrl, ContentDocumentId, FileExtension, Title FROM ContentVersion WHERE Id =:recordId];
            return contentList[0].VersionDataUrl;           
        } catch (Exception e) {
            //Utility.createErrorRecord(e.getMessage(), e.getStackTraceString(), e.getLineNumber(), e.getTypeName(), 'FileUploadController.getFileDetails');     
            throw new AuraHandledException(e.getMessage());
        }
    }

}