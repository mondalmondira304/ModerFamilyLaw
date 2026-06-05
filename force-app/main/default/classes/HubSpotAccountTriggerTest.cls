@isTest
public class HubSpotAccountTriggerTest {
    
    @isTest
    static void testAfterInsertFirstIteration() {
        // Prepare record type IDs for test accounts
        List<RecordType> recordTypes = [SELECT Id, DeveloperName FROM RecordType WHERE SObjectType = 'Account'];
        Map<String, Id> recordTypeMap = new Map<String, Id>();
        for (RecordType rt : recordTypes) {
            recordTypeMap.put(rt.DeveloperName, rt.Id);
        }

        // First iteration
        Test.startTest();
        Account account1 = new Account(
            FirstName = 'Test',
            LastName = 'Account1',
            RecordTypeId = recordTypeMap.get('Web_PC'),
            PersonEmail = 'test1@example.com'
        );
        insert account1;
        Test.stopTest();

        // Perform assertions for the first iteration
        List<DelayedFormSubmission__c> submissions1 = [SELECT Id, Email__c, Status__c FROM DelayedFormSubmission__c WHERE Email__c = 'test1@example.com'];
        System.assertEquals(1, submissions1.size(), 'Expected 1 delayed form submission to be inserted for the first iteration.');
        System.assertEquals('Pending', submissions1[0].Status__c);
        System.assertNotEquals(null, submissions1[0].Email__c);
    }
    
    @isTest
    static void testAfterInsertSecondIteration() {
        // Prepare record type IDs for test accounts
        List<RecordType> recordTypes = [SELECT Id, DeveloperName FROM RecordType WHERE SObjectType = 'Account'];
        Map<String, Id> recordTypeMap = new Map<String, Id>();
        for (RecordType rt : recordTypes) {
            recordTypeMap.put(rt.DeveloperName, rt.Id);
        }

        // Second iteration
        Test.startTest();
        Account account2 = new Account(
            FirstName = 'Test',
            LastName = 'Account2',
            RecordTypeId = recordTypeMap.get('Potential_Client'),
            PersonEmail = 'test2@example.com'
        );
        insert account2;
        Test.stopTest();

        // Perform assertions for the second iteration
        List<DelayedFormSubmission__c> submissions2 = [SELECT Id, Email__c, Status__c FROM DelayedFormSubmission__c WHERE Email__c = 'test2@example.com'];
        System.assertEquals(1, submissions2.size(), 'Expected 1 delayed form submission to be inserted for the second iteration.');
        System.assertEquals('Pending', submissions2[0].Status__c);
        System.assertNotEquals(null, submissions2[0].Email__c);
    }
    
    @isTest
    static void testAfterInsertThirdIteration() {
        // Prepare record type IDs for test accounts
        List<RecordType> recordTypes = [SELECT Id, DeveloperName FROM RecordType WHERE SObjectType = 'Account'];
        Map<String, Id> recordTypeMap = new Map<String, Id>();
        for (RecordType rt : recordTypes) {
            recordTypeMap.put(rt.DeveloperName, rt.Id);
        }

        // Third iteration
        Test.startTest();
        Account account3 = new Account(
            FirstName = 'Test',
            LastName = 'Account3',
            RecordTypeId = recordTypeMap.get('ZCC_Contact'),
            PersonEmail = 'test3@example.com'
        );
        insert account3;
        Test.stopTest();

        // Perform assertions for the third iteration
        List<DelayedFormSubmission__c> submissions3 = [SELECT Id, Email__c, Status__c FROM DelayedFormSubmission__c WHERE Email__c = 'test3@example.com'];
        System.assertEquals(1, submissions3.size(), 'Expected 1 delayed form submission to be inserted for the third iteration.');
        System.assertEquals('Pending', submissions3[0].Status__c);
        System.assertNotEquals(null, submissions3[0].Email__c);
    }
}