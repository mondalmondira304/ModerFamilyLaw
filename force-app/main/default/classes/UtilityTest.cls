@IsTest
private class UtilityTest {
    private static Id prsnAccountRecTypeId = Schema.SObjectType.Account.getRecordTypeInfosByDeveloperName().get('PersonAccount').getRecordTypeId();

    @testSetup
    private static void doTestDataSetup(){
        UserRole testRole = new UserRole(DeveloperName = 'FTC_AttorneysTest', Name = 'FTC Attorneys');
        insert testRole;
        Profile proCom = [SELECT Id FROM Profile WHERE Name = 'Customer Community User' LIMIT 1];
        Profile profileAdmin = [SELECT Id FROM Profile WHERE Name = 'System Administrator' LIMIT 1];
        List<UserRole> testRoles = new List<UserRole>([SELECT Id FROM UserRole WHERE DeveloperName = 'FTC_AttorneysTest' LIMIT 1]);

        User testAdmin = new User(Alias = 'te1234', Email='testuse1234@exampleuser.com', 
                            EmailEncodingKey='UTF-8', LastName='testuse1234', 
                            LanguageLocaleKey='en_US', LocaleSidKey='en_US', 
                            ProfileId = profileAdmin.Id, TimeZoneSidKey='America/Los_Angeles', 
                            UserName='testuse1234@exampleuser.com', UserRoleId = testRoles[0].Id, IsActive = TRUE);
        insert testAdmin;    

        System.runAs(testAdmin){
            Account trainingAcc = new Account();
            trainingAcc.RecordTypeId = prsnAccountRecTypeId;
            trainingAcc.FirstName = 'Test Account';
            trainingAcc.LastName = 'lname';
            trainingAcc.PersonEmail = 'test@test.com';
            trainingAcc.Hire__c = false;
            insert trainingAcc;

            Account acc = [SELECT PersonContactId FROM Account LIMIT 1];        

            User tUser = new User(Alias = 'te1234', Email='test@test.com', ContactId=acc.PersonContactId,
                        EmailEncodingKey='UTF-8', FirstName='Test Account', LastName='lname', 
                        LanguageLocaleKey='en_US', LocaleSidKey='en_US', 
                        ProfileId = proCom.Id, TimeZoneSidKey='America/Los_Angeles', 
                        UserName='test@test.com', IsActive = TRUE);
            insert tUser;
        }
    }

    @IsTest
    static void errorLogCreationTest() {
        Utility.createErrorRecord('test message','test stack trace',1,'test error type','test procname');
        List<ErrorLog__c> errorLogs=[select id, name from ErrorLog__c];
        System.assert(errorLogs.size()>1);      
    }
    @IsTest
    static void futureErrorLogCreationTest() {
        Test.startTest();
            Utility.createFutureErrorRecord('test message','test stack trace',1,'test error type','test procname');
        Test.stopTest();
        List<ErrorLog__c> errorLogs=[select id, name from ErrorLog__c];
        System.assert(errorLogs.size()>1);      
    }

    @IsTest 
    static void createErrorRecordForInvocableActionTest(){
        Utility.ErrorClass e = new Utility.ErrorClass();
        e.exceptionMessage='Test Message';
        e.procname='Test Procedure';
        List<Utility.ErrorClass> errors= new List<Utility.ErrorClass>{e};
        Test.startTest();
            Utility.createErrorRecordForInvocableAction(errors);
        Test.stopTest();
        List<ErrorLog__c> errorLogs=[select id, name from ErrorLog__c];
        System.assert(errorLogs.size()>1);        
    }

    @isTest
    private Static void testEmailChange(){
        Account acc = [SELECT Id, PersonEmail, IsCustomerPortal FROM Account WHERE PersonEmail = 'test@test.com' LIMIT 1];
        acc.PersonEmail = 'test55@test.com';
        update acc;
        Map<String,String> emailMap = new Map<String,String>{'test@test.com'=>'test55@test.com'};
        //run future method:
        Utility.updateUserRecords(emailMap);
    }

}