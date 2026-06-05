@isTest
public class customForgotPasswordControllerTest {

    @testSetup
    private static void doTestDataSetup(){
        //RecordType trainingRecId =  [SELECT Id FROM RecordType WHERE Name = 'Training' and SObjectType = 'Account'];
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
            trainingAcc.FirstName = 'Test Account';
            trainingAcc.LastName = 'lname';
            //trainingAcc.RecordType = trainingRecId;
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

    @isTest
    static void testLogPassReset() {
        Test.startTest();
        customForgotPasswordController.logPassReset('test@test.com');
        Test.stopTest();
    }

    @isTest
    static void testLogPassResetEmpty() {
        Test.startTest();
        customForgotPasswordController.logPassReset('');
        Test.stopTest();
    }
}