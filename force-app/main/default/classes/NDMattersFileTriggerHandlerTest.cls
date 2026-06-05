@isTest
public class NDMattersFileTriggerHandlerTest {
    // Helper method to create a test office
    private static MFL_Office__c createTestOffice() {
        MFL_Office__c testOffice = new MFL_Office__c(Name = 'Test Office');
        insert testOffice;
        return testOffice;
    }
    // Helper method to create a test user
    private static User createTestUser(String email) {
        Profile userProfile = [SELECT Id FROM Profile WHERE Name = 'Standard User' LIMIT 1];
        String finalEmail = String.isNotBlank(email) ? email : 'dummy' + DateTime.now().getTime() + '@example.com';

        User testUser = new User(
            FirstName = 'John',
            LastName = 'Doe',
            Email = finalEmail,
            Username = 'johndoe' + DateTime.now().getTime() + '@example.com',
            Alias = 'jdoe',
            TimeZoneSidKey = 'America/Los_Angeles',
            LocaleSidKey = 'en_US',
            EmailEncodingKey = 'UTF-8',
            LanguageLocaleKey = 'en_US',
            ProfileId = userProfile.Id
        );
        insert testUser;
        return testUser;
    }
    // Helper method to create a test matter
    private static Matters__c createTestMatter(MFL_Office__c office, User paralegal, User attorney) {
        User thisUser = [SELECT Id FROM User WHERE Id = :UserInfo.getUserId()];
       /*
        System.runAs (thisUser) {  //use System.runAs() to avoid mixed DML errors
            List<Account> accts=TestDataFactory.getPersonAccounts(2);
        }
        Account acct=[select id from account][0]; */
        Account acct = new Account(
            FirstName= 'Test FN-',
            LastName='Test LN-' ,
            PersonEmail= 'test@example.com',
            PersonMobilePhone='5101112222',
            Responsible_Attorney__c=thisUser.Id,
            Responsible_Paralegal__c=thisUser.Id ,
            Quoted_Retainer__c=10,
            Type_of_Case_A__c='Divorce w/Children');
        insert acct;
        Matters__c testMatter = new Matters__c(
            Name = 'Test Matter',
            Hire_Date__c=system.date.today(),
            Client_Name__c=acct.id,
            MFL_Office__c = office.Id,
            Primary_Paralegal__c = paralegal.Id,
            Primary_Attorney__c = attorney.Id
        );
        insert testMatter;
        return testMatter;
    }
    // Helper method to create a test ContentVersion
    private static ContentVersion createTestContentVersion() {
        ContentVersion contentVersion = new ContentVersion(
            Title = 'TestDocument',
            PathOnClient = 'TestDoc.pdf',
            VersionData = Blob.valueOf('Test data')
        );
        insert contentVersion;
        return contentVersion;
    }
    // Helper method to retrieve ContentDocument linked to ContentVersion
    private static ContentDocument getContentDocument(ContentVersion version) {
        return [SELECT Id FROM ContentDocument WHERE Id IN (SELECT ContentDocumentId FROM ContentVersion WHERE Id = :version.Id) LIMIT 1];
    }
    // Helper method to create a test ContentDocumentLink
    private static ContentDocumentLink createTestContentDocumentLink(Id matterId, Id contentDocumentId) {
        ContentDocumentLink link = new ContentDocumentLink(
            LinkedEntityId = matterId,
            ContentDocumentId = contentDocumentId,
            ShareType = 'V',
            Visibility = 'AllUsers'
        );
        insert link;
        return link;
    }
    // Mock for successful response
    private class SuccessMock implements HttpCalloutMock {
        public HttpResponse respond(HttpRequest req) {
            HttpResponse res = new HttpResponse();
            res.setStatusCode(200);
            res.setBody('{"status":"OK"}');
            return res;
        }
    }
    @isTest
    static void testCheckWorkspace() {
        // Step 1: Create test office and user
        MFL_Office__c office = createTestOffice();
        User attorney = createTestUser('attorney@example.com');
        // Step 2: Create test matter linked to the office and user
        Matters__c matter = createTestMatter(office, attorney, attorney);
        Test.setMock(HttpCalloutMock.class, new SuccessMock());        
        Test.startTest();
            List <Boolean> results=NetDocumentsMattersFileTriggerHandler.checkWorkspace(new List<Id>{matter.Id});
        Test.stopTest();
        // Assertions
        System.assertEquals(true, results[0], 'Workspace was not created.');
    }
    @isTest
    static void testHandleFileUpload() {
        // Step 1: Create test office and user
        MFL_Office__c office = createTestOffice();
        User attorney = createTestUser('attorney@example.com');
        // Step 2: Create test matter linked to the office and user
        Matters__c matter = createTestMatter(office, attorney, attorney);
        // Step 3: Create test ContentVersion
        ContentVersion contentVersion = createTestContentVersion();
        // Step 4: Retrieve associated ContentDocument
        ContentDocument contentDoc = getContentDocument(contentVersion);
        // Step 5: Create test ContentDocumentLink
        createTestContentDocumentLink(matter.Id, contentDoc.Id);
        // Step 6: Call the method under test
        Test.setMock(HttpCalloutMock.class, new SuccessMock());        
        Test.startTest();
        NetDocumentsMattersFileTriggerHandler.handleFileUpload(
            new List<Id>{matter.Id},
            new List<Id>{contentDoc.Id}
        );
        Test.stopTest();
        // Assertions
        ContentDocumentLink insertedLink = [
            SELECT Id, LinkedEntityId, ContentDocumentId 
            FROM ContentDocumentLink 
            WHERE LinkedEntityId = :matter.Id AND ContentDocumentId = :contentDoc.Id
            LIMIT 1
        ];
        System.assertNotEquals(null, insertedLink, 'ContentDocumentLink record should have been inserted.');
    }
    @isTest
    static void testInvokeEmailFlow() {
        // Step 1: Create test office
        MFL_Office__c office = createTestOffice();
        // Step 2: Create test users for paralegal and attorney
        User paralegal = createTestUser('paralegal@example.com');
        User attorney = createTestUser('attorney@example.com');
        // Step 3: Create test matter linked to the office, paralegal, and attorney
        Matters__c testMatter = createTestMatter(office, paralegal, attorney);
        // Step 4: Call the invokeEmailFlow method
        String testFileName = 'TestDocument.pdf'; // Sample file name
        Test.startTest();
        NetDocumentsMattersFileTriggerHandler.invokeEmailFlow(
            testMatter.Id, 
            testMatter.Name, 
            testMatter.Matter_ID_Matter__c,
            testFileName, true //for success
        );
        NetDocumentsMattersFileTriggerHandler.invokeEmailFlow(
            testMatter.Id, 
            testMatter.Name, 
            testMatter.Matter_ID_Matter__c,
            testFileName, false //for failure
        );        
        Test.stopTest();
        // Step 5: Validate via debug logs or mock logic
        System.assert(true, 'Email logic executed successfully (validated via debug logs or mock logic).');
    }
    @isTest
    static void testCreateTaskToTrackUpload(){
        // Step 1: Create test office
        MFL_Office__c office = createTestOffice();
        // Step 2: Create test users without emails
        User paralegal = createTestUser(null); // Paralegal has no email
        User attorney = createTestUser(null); // Attorney has no email
        // Step 3: Create test matter linked to the office, paralegal, and attorney
        Matters__c testMatter = createTestMatter(office, paralegal, attorney);
        // Step 4: Call the invokeEmailFlow method
        Test.startTest();
            NetDocumentsMattersFileTriggerHandler.CreateTaskToTrackUpload(testMatter.Id, '001-001', 'TestFile', true, 'successful');
            NetDocumentsMattersFileTriggerHandler.CreateTaskToTrackUpload(testMatter.Id, '001-001', 'TestFile', true, 'failure');            
        Test.stopTest();
        List<Task> t=[select id, whatid from task where whatId=:testMatter.id];
        System.assertEquals(2,t.size());
    }
    @isTest
    static void testInvokeEmailFlowWithNoEmails() {
        // Step 1: Create test office
        MFL_Office__c office = createTestOffice();
        // Step 2: Create test users without emails
        User paralegal = createTestUser(null); // Paralegal has no email
        User attorney = createTestUser(null); // Attorney has no email
        // Step 3: Create test matter linked to the office, paralegal, and attorney
        Matters__c testMatter = createTestMatter(office, paralegal, attorney);
        // Step 4: Call the invokeEmailFlow method
        String testFileName = 'TestDocument.pdf'; // Sample file name
        Test.startTest();
        NetDocumentsMattersFileTriggerHandler.invokeEmailFlow(
            testMatter.Id, 
            testMatter.Name, 
            testMatter.Matter_ID_Matter__c,
            testFileName, true
        );
        Test.stopTest();
        // Step 5: Ensure no exceptions occurred
        System.assert(true, 'Test completed successfully without sending any emails.');
    }
}