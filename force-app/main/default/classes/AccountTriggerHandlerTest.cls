@isTest
public class AccountTriggerHandlerTest {
    
    
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
    private static void testPortalEmail(){
        Test.startTest();
        List<User> usList = [SELECT Id, ContactId, AccountId FROM User WHERE Email = 'test@test.com'];    
        AccountUtils.emailRequest req =new  AccountUtils.emailRequest();
        req.theUser=usList[0];
        req.emailTemplateDeveloperName='Welcome_Email_New';
        List<AccountUtils.emailRequest> reqList= new List<AccountUtils.emailRequest>{req};
        AccountUtils.updateUserList(reqList);
        Test.stopTest();
    }
    
    @isTest
    private Static void accTriggerTest(){
        account acc = [select id,LastName from account limit 1];
        acc.lastName = 'testing';
        update acc;
    }
    
    //Added by Ashok
    @isTest
    private Static void updateEngagementStatusTimeTest1(){
        account acc = [select id,Attorney_Follow_up_on_FA__c from account limit 1];
        acc.Attorney_Follow_up_on_FA__c = 'SMS Sent';
        update acc;
    }
    
    //Added by Ashok
    @isTest
    private Static void updateEngagementStatusTimeTest2(){
        account acc = [select id,Attorney_Follow_up_on_FA__c from account limit 1];
        acc.Attorney_Follow_up_on_FA__c = 'Email Sent';
        update acc;
    }
    
    
    //Added by Ashok
    @isTest
    private Static void updateEngagementStatusTimeTest3(){
        account acc = [select id,Attorney_Follow_up_on_FA__c from account limit 1];
        acc.Attorney_Follow_up_on_FA__c = 'Left Voicemail';
        update acc;
    }
    
    //Added by Ashok
    @isTest
    private Static void updateEngagementStatusTimeTest4(){
        account acc = [select id,Attorney_Follow_up_on_FA__c from account limit 1];
        acc.Attorney_Follow_up_on_FA__c = 'Waiting for Payment';
        update acc;
    }
    
    //Added by Ashok
    @isTest
    private Static void updateEngagementStatusTimeTest5(){
        account acc = [select id,Attorney_Follow_up_on_FA__c from account limit 1];
        acc.Attorney_Follow_up_on_FA__c = 'Follow up in 3 days';
        update acc;
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