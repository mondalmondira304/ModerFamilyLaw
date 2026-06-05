@isTest
public class UserTriggerHandlerTest {
    
    @testSetup
    private static void doTestDataSetup(){
        Profile profileId = [SELECT Id FROM Profile WHERE Name = 'Attorney/Paralegal' LIMIT 1];
        UserRole testRole = new UserRole(DeveloperName = 'FTC_AttorneysTest', Name = 'FTC Attorneys');
        insert testRole;
        User usr = new User(LastName = 'test Lname',
                            FirstName='test fname',
                            Alias = 'jliv',
                            Email = 'testemailTriggerTest@dummyTestEmail.com',
                            Username = 'LOLP{OPOL.5623423.4556@argsdfgsdfgsdfgqertq314t3q.com',
                            ProfileId = profileId.id,
                            TimeZoneSidKey = 'GMT',
                            LanguageLocaleKey = 'en_US',
                            EmailEncodingKey = 'UTF-8',
                            LocaleSidKey = 'en_US',
                            UserRoleId = testRole.Id
                           );
        
        insert usr;
        System.runAs(usr){
            //RecordType trainingRecId =  [SELECT Id FROM RecordType WHERE Name = 'Training' and SObjectType = 'Account'];
        Account trainingAcc = new Account();
        trainingAcc.FirstName = 'Test Account';
        trainingAcc.LastName = 'lname';
        //trainingAcc.RecordType = trainingRecId;
        trainingAcc.Hire__c = false;
        insert trainingAcc;
        
        Jurisdiction__c juri = new Jurisdiction__c();
        juri.name = 'Test Juri Name';
        insert juri;
        
        MFL_Office__c officeMFL = new MFL_Office__c();
        officeMFL.name = 'Test Office Name';
        insert officeMFL;
        
        Matters__c mat = new Matters__c();
        mat.Client_Name__c = trainingAcc.Id;
        mat.Matter_ID_Client__c = '1234';
        mat.Matter_ID_Matter__c = '123';
        mat.Jurisdiction__c = juri.id;
        mat.MFL_Office__c = officeMFL.id;
        mat.Case_Type__c = 'Adoption';
        mat.Hire_Date__c = Date.today();
        insert mat;
        }
        
    }
    
    @isTest
    private static void doTestAfterUpdateTest(){
        
        user usr = [select id,isActive from user where email='testemailTriggerTest@dummyTestEmail.com' limit 1];
        usr.isActive = false;
        update usr;     
        test.startTest();
        usr.isActive = true;
        update usr;
        test.stopTest();
    }
}