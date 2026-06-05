@isTest
private class matterTriggerBehavior {   
   static void makeData(){
      Profile profileId = [SELECT Id FROM Profile WHERE Name = 'Attorney/Paralegal' LIMIT 1];        
      User usr = new User(LastName = 'LIVESTON',
                         FirstName='JASON',
                         Alias = 'jliv',
                         Email = 'jason.liveston@asdf.com',
                         Username = 'json456234234556@examples.com',
                         ProfileId = profileId.id,
                         TimeZoneSidKey = 'GMT',
                         LanguageLocaleKey = 'en_US',
                         EmailEncodingKey = 'UTF-8',
                         LocaleSidKey = 'en_US'
                         );

      insert usr;
      
      RecordType personAccountRecordType =  [SELECT Id FROM RecordType WHERE Name = 'Person Account' and SObjectType = 'Account'];
      Account newPersonAccount = new Account();

      newPersonAccount.FirstName = 'Fred';
      newPersonAccount.LastName = 'Smith';
      newPersonAccount.PersonEmail = 'fred@test.com';
      newPersonAccount.RecordTypeId = personAccountRecordType.Id;
      insert newPersonAccount;  
      
      Jurisdiction__c juri = new Jurisdiction__c();
      juri.name = 'Test Juri Name';
      insert juri;

      MFL_Office__c officeMFL = new MFL_Office__c();
      officeMFL.name = 'Test Office Name';
      insert officeMFL;
        
      List<Matters__c> testMatterList = new List<Matters__c>();
/*
      Matters__c mat = new Matters__c();
      mat.Client_Name__c = newPersonAccount.Id;
      mat.Matter_ID_Client__c = '1234';
      mat.Matter_ID_Matter__c = '123';
      mat.Jurisdiction__c = juri.id;
      mat.MFL_Office__c = officeMFL.id;
      mat.case_type__c = 'Adoption';
      mat.hire_date__c = Date.today();
      testMatterList.add(mat)     ;

      insert testMatterList;*/
   }   
   
   //GIVEN  a matter record is created with client (account) linked
   //WHEN   after insert
   //THEN   matter_share record is created for users for the matter record   
   @isTest
   static void shouldCreateMatterShare(){
      makeData();
      Account personAccount = [SELECT id FROM ACCOUNT LIMIT 1];
      Jurisdiction__c juri1 = new Jurisdiction__c();
      juri1.name = 'Test Juri Namasdfe';
      insert juri1;

      MFL_Office__c officeMFL1 = new MFL_Office__c();
      officeMFL1.name = 'Test Officeasdf Name';
      insert officeMFL1;

      Matters__c mat = new Matters__c();
      mat.Client_Name__c = personAccount.id;
      mat.Matter_ID_Client__c = '1234';
      mat.Matter_ID_Matter__c = '123';
      mat.Jurisdiction__c = juri1.id;
      mat.MFL_Office__c = officeMFL1.id;
      mat.case_type__c = 'Criminal';  //a client can't have two matters with the same type
      mat.hire_date__c = Date.today();

      user usr= [SELECT Id FROM User where email='jason.liveston@asdf.com' LIMIT 1];
      
      test.startTest();
         insert mat;
         MattersTriggerHandler.createObjectShare('Matters__c', [SELECT ID FROM MATTERS__C LIMIT 1].id, usr.Id);
      test.stopTest();

      system.assertEquals(mat.id, [SELECT id, parentID FROM MATTERS__SHARE where parentID =: mat.id LIMIT 1].parentID);
   }

}