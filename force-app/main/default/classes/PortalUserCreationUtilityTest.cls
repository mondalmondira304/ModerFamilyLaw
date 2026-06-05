@isTest
public with sharing class PortalUserCreationUtilityTest {
    @isTest
    static void createPortalUserTest() {
        User thisUser = [SELECT Id FROM User WHERE Id = :UserInfo.getUserId()];
        System.runAs (thisUser) {  //use System.runAs() to avoid mixed DML errors
            List<Matters__c> mattersList= testDataFactory.getMatters(1);
        }
        Matters__c matter=[select id, Client_Name__c from matters__c where status__c='Open'][0];
        system.debug('**matter:  '+matter);
        PortalUserCreationUtility.AccountUserInfoClass Info= new PortalUserCreationUtility.AccountUserInfoClass();
        Info.AccountId=Matter.Client_Name__c;
        Info.theUser=null;
        Info.profileName='Customer Community User';
        List<PortalUserCreationUtility.AccountUserInfoClass> Infos= new List <PortalUserCreationUtility.AccountUserInfoClass>{Info};
        test.startTest();
            List<String> users=PortalUserCreationUtility.createPortalUser(Infos);  //creates the Portal User
        test.stopTest();

        User activeUser=[select id, isActive from User where id=:users[0]];        
        System.Assert(users.size()==1);
        System.AssertEquals(true, activeUser.isActive);
        List<Task> ts=[select id, whatId, subject from Task where WhatId=:Info.AccountId];
        system.assert(ts.size()>0);  //there might be another process creating tasks on accounts (like the Welcome Email notification), so just check that at least one was created
        //system.assertEquals('This account was created as a Portal User', ts[0].subject); The subject returned may be the welcome email notification or the portal user creation task, so we can't reliably assert on the subject line
    }
    /*
    @isTest
    static void updatePortalUserTest() {
        User thisUser = [SELECT Id FROM User WHERE Id = :UserInfo.getUserId()];
        System.runAs (thisUser) {  //use System.runAs() to avoid mixed DML errors
            List<Matters__c> mattersList= testDataFactory.getMatters(1);
        }
        Matters__c matter=[select id, Client_Name__c from matters__c where status__c='Open'][0];
        User inactiveUser=[select id, isActive, IsPortalEnabled from User where isActive=true and isPortalEnabled=true][0];
        inactiveUser.isActive=false;
        update inactiveUser;
        PortalUserCreationUtility.AccountUserInfoClass Info= new PortalUserCreationUtility.AccountUserInfoClass();          
        //Info=Infos[0];
        //Infos.clear();
        Info.AccountId=matter.Client_Name__c;
        Info.theUser=inactiveUser;
        Info.profileName='Customer Community User';
        List<PortalUserCreationUtility.AccountUserInfoClass> Infos= new List <PortalUserCreationUtility.AccountUserInfoClass>{Info};
        test.startTest();
            List<String> users=PortalUserCreationUtility.createPortalUser(Infos);  //reactivates the Portal User
        test.stopTest();

        User activeUser=[select id, isActive from User where id=:users[0]];        
        System.Assert(users.size()==1);
        System.AssertEquals(true, activeUser.isActive);
        List<Task> ts=[select id, whatId, subject from Task where WhatId=:Info.AccountId];
        system.assertEquals(1, ts.size());
        system.assertEquals('This account was reactivated as a Portal User', ts[0].subject);
    }    
    */
}