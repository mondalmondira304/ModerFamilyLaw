@isTest
public class NDFileTriggerTest {

    @isTest
    static void testNetDocumentsMattersFileTrigger() {
        // Setup test data
        // Create a related Office__c record (or the correct object linked to MFL_Office__c)
        MFL_Office__c testOffice = new MFL_Office__c(
            Name = 'Test Office'
        );
        insert testOffice;
        User thisUser = [SELECT Id FROM User WHERE Id = :UserInfo.getUserId()];
        System.runAs (thisUser) {  //use System.runAs() to avoid mixed DML errors
            List<Account> accts=TestDataFactory.getPersonAccounts(1);
        }
        Account acct=[select id from account][0];
        // Create a Matters__c record with required fields
        Matters__c testMatter = new Matters__c(
            Name = 'Test Matter',
            Hire_Date__c=system.date.today(),
            Client_Name__c=acct.id,
            MFL_Office__c = testOffice.Id // Reference the ID of the created Office record
        );
        insert testMatter;

        Credit_Card__c testCard = new Credit_Card__c(
            matter_id__c=testMatter.id,
            Name='Test'
        );
        insert testCard;        
        Other_Income__c testOtherIncome = new Other_Income__c(
            matter__c=testMatter.id,
            Name='Test'
        );
        insert testOtherIncome;       
        Utilites__c testUtilities = new Utilites__c(
            matter_name__c=testMatter.id
        );
        insert testUtilities;              
        // Create a ContentVersion record
        ContentVersion testVersion = new ContentVersion(
            Title = 'Test Document Version',
            PathOnClient = 'TestDoc.pdf',
            VersionData = Blob.valueOf('Test data')
        );
        insert testVersion;
        // Retrieve the associated ContentDocumentId
        ContentDocument contentDoc = [
            SELECT Id 
            FROM ContentDocument 
            WHERE Id IN (SELECT ContentDocumentId FROM ContentVersion WHERE Id = :testVersion.Id)
            LIMIT 1
        ];
        // Create a ContentDocumentLink linked to the Matters__c record
        ContentDocumentLink matterLink = new ContentDocumentLink(
            LinkedEntityId = testMatter.Id,
            ContentDocumentId = contentDoc.Id,
            ShareType = 'V',
            Visibility = 'AllUsers'
        );
        ContentDocumentLink creditLink = new ContentDocumentLink(
            LinkedEntityId = testCard.Id,
            ContentDocumentId = contentDoc.Id,
            ShareType = 'V',
            Visibility = 'AllUsers'
        );
        ContentDocumentLink otherIncomeLink = new ContentDocumentLink(
            LinkedEntityId = testOtherIncome.Id,
            ContentDocumentId = contentDoc.Id,
            ShareType = 'V',
            Visibility = 'AllUsers'
        );    
        ContentDocumentLink utilitiesLink = new ContentDocumentLink(
            LinkedEntityId = testUtilities.Id,
            ContentDocumentId = contentDoc.Id,
            ShareType = 'V',
            Visibility = 'AllUsers'
        );                       
        Test.startTest();
            // Insert the ContentDocumentLink to invoke the trigger
            insert matterLink;
            insert creditLink;
            insert otherIncomeLink;
            insert utilitiesLink;
        Test.stopTest();

        // Assertions
        // Verify the ContentDocumentLink record was inserted
        ContentDocumentLink insertedLink = [
            SELECT Id, LinkedEntityId, ContentDocumentId 
            FROM ContentDocumentLink 
            WHERE Id = :matterLink.Id
            LIMIT 1
        ];

        System.assertNotEquals(null, insertedLink, 'ContentDocumentLink record should have been inserted.');

        // Assert the job was enqueued (if applicable)
        Integer enqueuedJobsCount = [SELECT COUNT() FROM AsyncApexJob WHERE JobType = 'Queueable'];
        System.assert(enqueuedJobsCount > 0, 'A Queueable job should have been enqueued.');
    }
}