@isTest
public class FileUploadControllerTest {

    @testSetup
    static void setupTestData() {
        Account testAcc = new Account(Name = 'Test Account');
        insert testAcc;
    }

    @isTest
    static void testGetVersionDataUrl(){
        Account acc = [SELECT Id FROM Account LIMIT 1];
        String base64Data = EncodingUtil.base64Encode(Blob.valueOf('Test content'));
        
        ContentVersion cv = new ContentVersion(
            Title = 'FileForDetails.txt',
            PathOnClient = 'FileForDetails.txt',
            VersionData = EncodingUtil.base64Decode(base64Data),
            FirstPublishLocationId = acc.Id
        );
        insert cv;

        Test.startTest();
            String URL = FileUploadController.getVersionDataUrl(cv.Id);
        Test.stopTest();        
        system.assert(URL.contains('http'));
    }

    @isTest
    static void testGetAssociatedFiles() {
        Account acc = [SELECT Id FROM Account LIMIT 1];
        String base64Data = EncodingUtil.base64Encode(Blob.valueOf('Test content'));
        
        ContentVersion cv = new ContentVersion(
            Title = 'FileForDetails.txt',
            PathOnClient = 'FileForDetails.txt',
            VersionData = EncodingUtil.base64Decode(base64Data),
            FirstPublishLocationId = acc.Id
        );
        insert cv;

        Test.startTest();
            List<ContentVersion> uploadedCvs = FileUploadController.getAssociatedFiles(acc.Id);
        Test.stopTest();

        System.assertEquals(1, uploadedCvs.size());
    }

    @isTest
    static void testDeleteFileAndDocument() {
        Account acc = [SELECT Id FROM Account LIMIT 1];
        String fileName = 'DeleteTest.txt';
        String base64Data = EncodingUtil.base64Encode(Blob.valueOf('To be deleted'));
        List<ContentVersion> cvList= new List<ContentVersion>();

        ContentVersion cv = new ContentVersion(
            Title = fileName,
            PathOnClient = fileName,
            VersionData = EncodingUtil.base64Decode(base64Data),
            FirstPublishLocationId = acc.Id
        );
        insert cv;

        // Re-query to get ContentDocumentId
        cvList = [SELECT Id, ContentDocumentId FROM ContentVersion WHERE Id = :cv.Id];

        Test.startTest();
            FileUploadController.deleteFileAndDocument(cvList[0].Id);
        Test.stopTest();

        cvList = [SELECT Id, ContentDocumentId FROM ContentVersion WHERE Id = :cv.Id];
        System.assertEquals(0, cvList.size());
    }

    /* Everything below can be deleted once the new File Upload component is fully implemented */
    @isTest
    static void testUploadFile() {
        Account acc = [SELECT Id FROM Account LIMIT 1];

        String fileName = 'TestFile.txt';
        String fileContent = 'This is a test file';
        String base64Data = EncodingUtil.base64Encode(Blob.valueOf(fileContent));

        Test.startTest();
        String contentVersionId = FileUploadController.uploadFile(fileName, base64Data, acc.Id);
        Test.stopTest();

        System.assertNotEquals(null, contentVersionId);
    }

    @isTest
    static void testSaveFile() {
        Account acc = [SELECT Id FROM Account LIMIT 1];

        String fileName = 'TestFile2.txt';
        String fileContent = 'Another test file';
        String base64Data = EncodingUtil.base64Encode(Blob.valueOf(fileContent));

        Test.startTest();
        String contentVersionId = FileUploadController.saveFile(acc.Id, fileName, base64Data);
        Test.stopTest();

        System.assertNotEquals(null, contentVersionId);
    }

    @isTest
    static void testGetFileDetails() {
        Account acc = [SELECT Id FROM Account LIMIT 1];
        String base64Data = EncodingUtil.base64Encode(Blob.valueOf('Test content'));
        
        ContentVersion cv = new ContentVersion(
            Title = 'FileForDetails.txt',
            PathOnClient = 'FileForDetails.txt',
            VersionData = EncodingUtil.base64Decode(base64Data),
            FirstPublishLocationId = acc.Id
        );
        insert cv;

        Test.startTest();
        String versionDataUrl = FileUploadController.getFileDetails(cv.Id);
        Test.stopTest();

        System.assertNotEquals(null, versionDataUrl);
    }
    /*
    @isTest
    static void testUploadAttachment() {
        Account acc = [SELECT Id FROM Account LIMIT 1];
        String base64Data = EncodingUtil.base64Encode(Blob.valueOf('Attachment test'));
    
        // Insert ContentVersion WITHOUT setting FirstPublishLocationId
        ContentVersion cv = new ContentVersion(
            Title = 'Attachment.txt',
            PathOnClient = 'Attachment.txt',
            VersionData = EncodingUtil.base64Decode(base64Data)
        );
        insert cv;
    
        // Re-query to get ContentDocumentId
        ContentVersion fetchedCv = [
            SELECT Id, ContentDocumentId 
            FROM ContentVersion 
            WHERE Id = :cv.Id AND ContentDocumentId != null 
            LIMIT 1
        ];
    
        Test.startTest();
        FileUploadController.uploadAttachment(fetchedCv.Id, acc.Id);
        Test.stopTest();
    
        List<ContentDocumentLink> links = [
            SELECT Id, ContentDocumentId 
            FROM ContentDocumentLink 
            WHERE LinkedEntityId = :acc.Id
        ];
        System.assertEquals(1, links.size());
    }
    */

    @isTest
    static void testUploadFile1() {
        Account acc = [SELECT Id FROM Account LIMIT 1];
        String fileName = 'UploadFile1.txt';
        String fileContent = 'Upload file 1 content';
        String base64Data = EncodingUtil.base64Encode(Blob.valueOf(fileContent));

        Test.startTest();
        FileUploadController.uploadFile1(acc.Id, fileName, base64Data);
        Test.stopTest();

        List<ContentVersion> cvs = [SELECT Id FROM ContentVersion WHERE Title = :fileName];
        System.assertEquals(1, cvs.size());
    }
    

}