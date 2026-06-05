@isTest
public class NDFileUploadQueueableTest {

    @isTest
    static void testExecute() {
        // Arrange
        MFL_Office__c testOffice = new MFL_Office__c(Name = 'Test Office');
        insert testOffice;
        User thisUser = [SELECT Id FROM User WHERE Id = :UserInfo.getUserId()];
        Account acct = new Account(
            FirstName= 'Test FN2-',
            LastName='Test LN2-' ,
            PersonEmail= 'test2@example.com',
            PersonMobilePhone='5101112222',
            Responsible_Attorney__c=thisUser.Id,
            Responsible_Paralegal__c=thisUser.Id ,
            Quoted_Retainer__c=10,
            Type_of_Case_A__c='Divorce w/Children');
        insert acct;
        Matters__c testMatter = new Matters__c(
            Name = 'Test Matter',
            Hire_Date__c=system.date.today(),
            Client_name__c=acct.id,
            MFL_Office__c = testOffice.Id,
            Matter_ID_Client__c = '12345',
            Matter_ID_Matter__c = '123'
        );
        insert testMatter;

        ContentVersion testVersion = new ContentVersion(
            Title = 'Test Document',
            PathOnClient = 'TestDocument.pdf',
            VersionData = Blob.valueOf('Test file content')
        );
        insert testVersion;

        ContentDocument contentDoc = [
            SELECT Id 
            FROM ContentDocument 
            WHERE Id IN (SELECT ContentDocumentId FROM ContentVersion WHERE Id = :testVersion.Id)
            LIMIT 1
        ];

        Test.setMock(HttpCalloutMock.class, new MockHttpCalloutSuccess());

        Test.startTest();
            NetDocumentsFileUploadQueueable queueableJob = new NetDocumentsFileUploadQueueable(
                new List<Id>{testMatter.Id}, 
                new List<Id>{contentDoc.Id}
            );
            System.enqueueJob(queueableJob);
        Test.stopTest();
        List<ErrorLog__c> errors = [ SELECT ErrorMessage__c FROM ErrorLog__c ];
        System.assertEquals(0, errors.size());
    }

    private class MockHttpCalloutSuccess implements HttpCalloutMock {
        public HttpResponse respond(HttpRequest req) {
            HttpResponse res = new HttpResponse();
            res.setStatusCode(200);
            res.setHeader('Content-Type', 'application/json');
            res.setBody('{"message":"File uploaded successfully"}');
            return res;
        }
    }
}