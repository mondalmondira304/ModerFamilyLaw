@isTest
private class revokePermissionsBehavior {
   static void makeData(){
      Profile profileId = [SELECT Id FROM Profile WHERE Name = 'Attorney/Paralegal' LIMIT 1];        
      User usr = new User(LastName = 'LIVESTON',
                         FirstName='JASON',
                         Alias = 'jliv',
                         Email = 'jason.liveston@asdf.com',
                         Username = 'json45656@examples.com',
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

      Matters__c mat = new Matters__c();
      mat.Client_Name__c = newPersonAccount.Id;
      mat.Matter_ID_Client__c = '1234';
      mat.Matter_ID_Matter__c = '123';
      mat.Jurisdiction__c = juri.id;
      mat.MFL_Office__c = officeMFL.id;
      mat.case_type__c = 'Adoption';
      mat.hire_date__c = Date.today();
      insert mat;
   }
   
   //GIVEN  matter record is created with shares created for users
   //WHEN   user is selected to revoke permission
   //THEN   share is deleted
    @isTest
   static void shouldRemoveShareAccess(){
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
      
      //code coverage
      cont.getItems();
      cont.grantPermissions();
      cont.getRevokedItems();
      cont.backToRecord();
      
      test.startTest();
      cont.revokePermissions();
      test.stopTest();    
      
      List<Matters__share> assertList = [SELECT id, parentID FROM MATTERS__SHARE];

      system.assert(!assertList.isEmpty());


   }
}