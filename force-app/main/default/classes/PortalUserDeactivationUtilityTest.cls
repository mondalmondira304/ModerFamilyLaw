@isTest
public with sharing class PortalUserDeactivationUtilityTest {
    @isTest
    static void createPortalUserTest() {
        UserTriggerHandler.doNotRunSharingLogic=true;
        User thisUser = [SELECT Id FROM User WHERE Id = :UserInfo.getUserId()];
        System.runAs (thisUser) {  //use System.runAs() to avoid mixed DML errors
            Account client=TestDataFactory.getPersonAccounts(1, 'Client')[0];
            Matters__c clientMatter=TestDataFactory.getSingleMatter('Closed', client.Id);
            Account pc=TestDataFactory.getPersonAccounts(1, 'Potential Client')[0];
            pc.send_credit_request__c=true;
            pc.Credit_Check_Complete__c=true;
            pc.Credit_Report_Link__c='www.test.com';
            update pc;

            PortalUserCreationUtility.AccountUserInfoClass Info= new PortalUserCreationUtility.AccountUserInfoClass();
            Info.AccountId=client.Id;  //for the client account
            Info.theUser=null;
            Info.profileName='Customer Community User';
            List<PortalUserCreationUtility.AccountUserInfoClass> Infos= new List <PortalUserCreationUtility.AccountUserInfoClass>{Info};
            List<String> users=PortalUserCreationUtility.createPortalUser(Infos); 
            
            Info= new PortalUserCreationUtility.AccountUserInfoClass();
            Info.AccountId=pc.Id;  //for the PC account
            Info.theUser=null;
            Info.profileName='Customer Community User';
            Infos= new List <PortalUserCreationUtility.AccountUserInfoClass>{Info};        
            users=PortalUserCreationUtility.createPortalUser(Infos); 

        }
        test.startTest();
            List<User> u=PortalUserDeactivationUtility.deactivatePortaUser();  //deactivate the the Portal Users
        test.stopTest();
        //requery to get the user associated with the client
        Account client= [select id, name, (select id, name, profile.name, isactive, AccountId__c from users ) from account where RecordType.Name='Client'][0];
        User portalUser=client.users[0];
        system.assertEquals(false, portalUser.isActive);
        //requery to get the user associated with the pc
        //Account pc=[select id, name, (select id, name, profile.name, isactive, AccountId__c from users ) from account where RecordType.Name='Potential Client'][0];
        //User pcUser=pc.users[0];
        //system.assertEquals(false, pcUser.isActive);
    }
}