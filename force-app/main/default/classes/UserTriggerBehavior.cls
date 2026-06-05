@isTest
private  class UserTriggerBehavior {
    private static User usr1 = new User();
    private static Profile pubProfileId = [SELECT Id FROM Profile WHERE Name = 'Attorney/Paralegal' LIMIT 1]; 
    
    static void makeData(){
      User thisUser = [SELECT Id FROM User WHERE Id = :UserInfo.getUserId()];
      System.runAs (thisUser) {  //use System.runAs() to avoid mixed DML errors
        Profile profileId = [SELECT Id FROM Profile WHERE Name = 'Attorney/Paralegal' LIMIT 1];        
        User usr = new User(LastName = 'LIVESTON',
                            FirstName='JASON',
                            Alias = 'jliv',
                            Email = 'jason.liveston@asdf.com',
                            Username = 'LOLP{OPOL.5623423.4556@argsdfgsdfgsdfgqertq314t3q.com',
                            ProfileId = profileId.id,
                            TimeZoneSidKey = 'GMT',
                            LanguageLocaleKey = 'en_US',
                            EmailEncodingKey = 'UTF-8',
                            LocaleSidKey = 'en_US'
                            );
        insert usr;
      }
       
       RecordType personAccountRecordType =  [SELECT Id FROM RecordType WHERE Name = 'Person Account' and SObjectType = 'Account'];
       Account newPersonAccount = new Account();
 
       newPersonAccount.FirstName = 'Fred';
       newPersonAccount.LastName = 'Smith';
       newPersonAccount.RecordType = personAccountRecordType;
       newPersonAccount.PersonEmail = 'test@test.com';
       insert newPersonAccount;    
       
       Jurisdiction__c juri = new Jurisdiction__c();
       juri.name = 'Test Juri Name';
       insert juri;

       MFL_Office__c officeMFL = new MFL_Office__c();
       officeMFL.name = 'Test Office Name';
       insert officeMFL;
              
       List<Matters__c> testMatterList = new List<Matters__c>();
 
       for(integer i = 0; i < 2; i++){
          Matters__c mat = new Matters__c();
          mat.Client_Name__c = newPersonAccount.Id;
          mat.Matter_ID_Client__c = '1234';
          mat.Matter_ID_Matter__c = '123';
          mat.Jurisdiction__c = juri.id;
          mat.MFL_Office__c = officeMFL.id;
          mat.hire_date__c = date.today();
          testMatterList.add(mat)     ;
       }
       insert testMatterList;
    }
    /*
    static void makeNewUser(){
        Profile profileId = [SELECT Id FROM Profile WHERE Name = 'Attorney/Paralegal' LIMIT 1];        
        usr1 = new User(LastName = 'LIVESTON',
                         FirstName='JASON',
                         middleName = 'T',
                         Alias = 'jliv',
                         Email = 'jason.liveston@asdf.com',
                         Username = 'json4565690-83459867983456897@examples2435632456.com',
                         ProfileId = profileId.id,
                         TimeZoneSidKey = 'GMT',
                         LanguageLocaleKey = 'en_US',
                         EmailEncodingKey = 'UTF-8',
                         LocaleSidKey = 'en_US'
                         );
    }*/


    //GIVEN  Users in existing org are placed into 1.10 compliance  (restriced access to matters) and the attorney/paralegal profile exists
    //WHEN   a new user is created and placed into the attorney/paralegal profile
    //THEN   the new user is granted share access to all existing matters in the org and existing users retain restriced access
    @isTest
    static void testExistingUserRestrictedAccess(){
      makeData();

      PageReference pageRef = Page.revokePermissions;
      Test.setCurrentPage(pageRef);
      Id matterId = [SELECT ID FROM Matters__c LIMIT 1].Id;
       Matters__c mat = [Select ID From Matters__c LIMIT 1];
      ApexPages.currentPage().getParameters().put('Id',matterId);
             
      ApexPages.StandardController sc = new ApexPages.StandardController(mat);
      revokePermissionsController cont = new revokePermissionsController(sc); 
     
      List<String> userNames = new List<String>();    
      User u = [SELECT ID, Name FROM USER LIMIT 1];
      userNames.add(u.Name);
      cont.setUsers(userNames);
      cont.revokePermissions();

      /*User thisUser = [SELECT Id FROM User WHERE Id = :UserInfo.getUserId()];
      System.runAs (thisUser) {  //use System.runAs() to avoid mixed DML errors
        makeNewUser();
        test.startTest();
        insert usr1;
        test.stopTest();        
      }*/

    }

    //GIVEN a large number of Matters and Accounts exist in the target org. Matters may or may not have an account linked
    //WHEN  User is created
    //THEN  Share records are created for each matter and relevent account for the new user
    @isTest
    static void testMassRecordUserAccessAccount(){
      List<Matters__c> testMatterList = new List<Matters__c>();
      List<Account> testAccountList = new List<Account>();

      RecordType personAccountRecordType =  [SELECT Id FROM RecordType WHERE Name = 'Person Account' and SObjectType = 'Account'];
      
      //for(integer i = 0; i < 75; i++){
      for(integer i = 0; i < 2; i++){        
        Account newPersonAccount = new Account();
        newPersonAccount.FirstName = 'Fred' + i;
        newPersonAccount.LastName = 'Smith';
        newPersonAccount.MiddleName = 'T';
        newPersonAccount.RecordType = personAccountRecordType;
        newPersonAccount.Hire__c = false;
        newPersonAccount.PersonEmail = 'test@test.com';
        testAccountList.add(newPersonAccount)  ;
      }
      
      insert testAccountList;
       
        Jurisdiction__c juri = new Jurisdiction__c();
        juri.name = 'Test Juri Name';
        insert juri;

       MFL_Office__c officeMFL = new MFL_Office__c();
       officeMFL.name = 'Test Office Name';      
       insert officeMFL;
       
 		Integer j = 0;
      //for(integer i = 0; i < 75; i++){
      for(integer i = 0; i < 2; i++){        
        Matters__c mat = new Matters__c();
        //if(j < 75){
        if(j < 2){          
          mat.Client_Name__c = testAccountList[j].Id;
          j++;
        }
        
        mat.Matter_ID_Client__c = '1234';
        mat.Matter_ID_Matter__c = '123';
        mat.Jurisdiction__c = juri.id;
        mat.MFL_Office__c = officeMFL.id;
        mat.hire_date__c = date.today();
        testMatterList.add(mat);
      }
      insert testMatterList;

      test.startTest();        
          //code coverage
          batchApexShares_AccountList bShares_acct = new batchApexShares_AccountList();
          bShares_acct.query = 'SELECT Id FROM ACCOUNT';
          bShares_acct.userList = [SELECT ID FROM User WHERE isActive = true AND Profile.Name = 'Attorney/Paralegal'];
          database.executeBatch(bShares_acct);          

          batchApexShares_MatterList bShares_matters = new batchApexShares_MatterList();
          bShares_matters.query = 'SELECT id,Client_Name__c,Opposing_Party_a__c FROM Matters__c';
          bShares_matters.userList = [SELECT ID FROM User WHERE isActive = true AND Profile.Name = 'Attorney/Paralegal'];
          database.executeBatch(bShares_matters);        

      test.stopTest(); 
    }

}