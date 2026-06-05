@isTest
private class VitalAccountControllerTest {

    @testSetup
    static void setupData() {
        // Account and Matter
        Account acc = new Account(FirstName='Test', LastName='User', personemail='test@test.com');
        insert acc;
        MFL_Office__c mflOffice = new MFL_Office__c(Name = 'Test');
        insert mflOffice;       
        Matters__c matter = new Matters__c(Name='Test Matter', Client_Name__c=acc.Id, MFL_Office__c = mflOffice.Id, Hire_Date__c=system.date.today());
        insert matter;
        // Employment__c record
        Employment__c emp = new Employment__c(Name='Test Employment', Employer_Phone__c='9876543210');
        insert emp;
    }    
    static testMethod void testVitalAccountControllerMethods() {
        Test.startTest();
        Account testAcc = new Account(
            FirstName = 'Test',
            LastName = 'User',
            PersonEmail = 'testuser@example.com',
            Phone = '1234567890'
        );
        insert testAcc;
        User testUser = [SELECT Id, IsActive, State FROM User WHERE Profile.Name='System Administrator' AND IsActive = TRUE LIMIT 1];
        System.runAs(testUser) {
            update testUser;
        }    
        Matters__c testMatter =[select name, client_name__c, status__c, MFL_Office__c, Hire_Date__c from Matters__c where name='Test Matter'][0];
        Blob fileBody = Blob.valueOf('Test File Content');
        String base64Data = EncodingUtil.base64Encode(fileBody);       
        testAcc.FirstName = 'Updated';
        Account updatedAcc = VitalAccountController.updateAccount(testAcc);
        System.assertEquals('Updated', updatedAcc.FirstName);
        testMatter.Name_Change__c = true;
        Matters__c updatedMatter = VitalAccountController.updateMatter(testMatter);
        System.assertEquals(true, updatedMatter.Name_Change__c);
        // Test getCurrentUserAccountId
        Id accId = VitalAccountController.getCurrentUserAccountId();
        // Test getAccountDetails
        //VitalAccountController.testAccountId = testAcc.Id;
        // VitalAccountController.VitalWrapper wrapper = VitalAccountController.getAccountDetails();
        VitalAccountController.getOpposingPartiesDetails(testAcc.Id);
        // Test getOpposingParties
        List<Matters__c> oppParties = VitalAccountController.getOpposingParties();
        System.assertNotEquals(null, oppParties);
        // Test getOpposingPartiesForSelectdMatter
        List<Matters__c> oppPartiesForMatter = VitalAccountController.getOpposingPartiesForSelectdMatter(testMatter.Id);
        System.assertNotEquals(null, oppPartiesForMatter);
        // Test getAllAccounts
        /*List<Account> allAccs = VitalAccountController.getAllAccounts();
        System.assert(allAccs.size() > 0);*/
        // Create a ContentDocumentLink to test getRelatedFiles
        ContentVersion cv = new ContentVersion(
            Title = 'TestFile',
            PathOnClient = 'TestFile.txt',
            VersionData = fileBody
        );
        insert cv;
        ContentVersion insertedCV = [SELECT Id, ContentDocumentId FROM ContentVersion WHERE Id = :cv.Id];
        ContentDocumentLink cdl = new ContentDocumentLink(
            LinkedEntityId = testAcc.Id,
            ContentDocumentId = insertedCV.ContentDocumentId,
            ShareType = 'V'
        );
        insert cdl;
        // List<ContentDocumentLink> files = VitalAccountController.getRelatedFiles(testAcc.Id);
        // System.assert(files.size() > 0);
        // Test uploadFile
        String fileName = 'SampleFile.pdf';
        // Id uploadedId = VitalAccountController.uploadFile(fileName, base64Data, testAcc.Id);
        // System.assertNotEquals(null, uploadedId);
        Test.stopTest();
    }
    @isTest 
    static void updateAccountException(){
        Account acc = new Account(FirstName='Test', LastName='User', personemail='test@test.com');
        try {
            Test.startTest();
            Account updatedAcc = VitalAccountController.updateAccount(acc);
        } catch (Exception e) {
            Test.stopTest();
            List<errorLog__c> errors=[select id from errorlog__c];
            system.assertEquals(errors.size(),1);
        }
    }
    @isTest 
    static void updateMattersException(){
        Matters__c matter = new Matters__c(Name='Test Matter',Hire_Date__c=system.date.today());
        try {
            Test.startTest();
            Matters__c updatedMatter = VitalAccountController.updateMatter(matter);
        } catch (Exception e) {            
            Test.stopTest();
            List<errorLog__c> errors=[select id from errorlog__c];
            system.assertEquals(errors.size(),1);
        }
    }  
    @isTest 
    static void updateMatterDateTimeException(){
        Matters__c matter = new Matters__c(Name='Test Matter',Hire_Date__c=system.date.today());        
        try {
            Test.startTest();
            Matters__c updatedMatter = VitalAccountController.updateMatterDateTime(matter);
        } catch (Exception e) {            
            Test.stopTest();
            List<errorLog__c> errors=[select id from errorlog__c];
            system.assertEquals(errors.size(),1);
        }
    }    
    @isTest 
    static void getOpposingPartiesForSelectdMatterException(){
        try {
            List<Matters__c> Matters = VitalAccountController.getOpposingPartiesForSelectdMatter('');
        } catch (Exception e) {
            List<errorLog__c> errors=[select id from errorlog__c];
            system.assertEquals(errors.size(),1);
        }
    }  
    @isTest
    static void UpdateRecordDetailExceptionBadObject() {
        Map<String, Object> accMap = new Map<String, Object>{
            'FirstName' => 'UpdatedFromJSON',
            'LastName' => 'LastnameUpdated',
            'Birthdate__c'=>System.date.today().addYears(-30),
            'Decision_making__c'=>true,
            'Attorney_Hourly_Rate__c'=>300
        };
        String jsonBody = JSON.serialize(accMap);
        try {
            Test.startTest();
                String recordId = VitalAccountController.updateRecordDetail(jsonBody, 'Invalid');
        } catch (Exception e) {
            Test.stopTest();  // to force the future method to run and commit an error record            
            List<errorLog__c> errors=[select id from errorlog__c];
            system.assertEquals(1,errors.size());
        }
    }         
    @isTest
    static void UpdateRecordDetailExceptionBadData() {
        Map<String, Object> accMap = new Map<String, Object>{
            'FirstName' => 'UpdatedFromJSON',
            'LastName' => 'LastnameUpdated',
            'Birthdate__c'=>System.date.today().addYears(-30),
            'Decision_making__c'=>true,
            'Attorney_Hourly_Rate__c'=>'A'
        };
        String jsonBody = JSON.serialize(accMap);
        try {
            Test.startTest();
                String recordId = VitalAccountController.updateRecordDetail(jsonBody, 'Account');
        } catch (Exception e) {
            Test.stopTest();  // to force the future method to run and commit an error record            
            List<errorLog__c> errors=[select id, ErrorMessage__c from errorlog__c];
            system.assertEquals(1, errors.size());
            system.assert(errors[0].ErrorMessage__c.contains('is supposed to be a decimal value but is not'));
        }
    }     
    @isTest
    static void GetObjectNameByIdException() {
        try {
            Test.startTest();
            String objectName = VitalAccountController.getObjectNameById('invalid');
        } catch (Exception e) {
            Test.stopTest();
            List<errorLog__c> errors=[select id from errorlog__c];
            system.assertEquals(errors.size(),1);
        }
    }         
    @isTest
    static void GettingEmployeePhoneException() {
        try {
            Test.startTest();
            Employment__c employment = VitalAccountController.gettingEmployeePhone('invalid');
        } catch (Exception e) {        
            Test.stopTest();
            List<errorLog__c> errors=[select id from errorlog__c];
            system.assertEquals(errors.size(),1);
        }
    }       
    @isTest
    static void testUpdateRecordDetailInsert() {
        Account testAcc = new Account(FirstName='Dynamic', LastName='InsertTest');
        insert testAcc;
        Map<String, Object> accMap = new Map<String, Object>{
            'FirstName' => 'UpdatedFromJSON',
            'LastName' => 'LastnameUpdated',
            'Birthdate__c'=>System.date.today().addYears(-30),
            'Decision_making__c'=>true,
            'Attorney_Hourly_Rate__c'=>300
        };
        String jsonBody = JSON.serialize(accMap);
        String recordId = VitalAccountController.updateRecordDetail(jsonBody, 'Account');
        System.assertNotEquals(null, recordId);
    }
    @isTest
    static void testUpdateRecordDetailUpdate() {
        Account testAcc = [SELECT Id, FirstName, LastName FROM Account LIMIT 1];
        Map<String, Object> accMap = new Map<String, Object>{
            'Id' => testAcc.Id,
            'FirstName' => 'UpdatedAgain',
            'Phone' => '9999999999'
        };
        String jsonBody = JSON.serialize(accMap);
        String recordId = VitalAccountController.updateRecordDetail(jsonBody, 'Account');
        System.assertEquals(testAcc.Id, recordId);
    }
    @isTest
    static void testGetObjectNameById() {
        Account acc = [SELECT Id FROM Account LIMIT 1];
        String objectName = VitalAccountController.getObjectNameById(acc.Id);
        System.assertEquals('Account', objectName);
    }
    @isTest
    static void testGettingEmployeePhone() {
        Employment__c emp = [SELECT Id, Employer_Phone__c FROM Employment__c LIMIT 1];
        Employment__c employe = VitalAccountController.gettingEmployeePhone(emp.Id);
        System.assertEquals('9876543210', employe.Employer_Phone__c);
    }
    @isTest static void testGetOpposingParties() {
        Test.startTest();
        List<Matters__c> result = VitalAccountController.getOpposingParties();
        Test.stopTest();

        System.assertNotEquals(null, result, 'Should return a list');
    }
    @isTest static void testGetOpposingPartiesForSelectdMatter() {
        Id testMatterId = [SELECT Id FROM Matters__c LIMIT 1].Id;
        Test.startTest();
        List<Matters__c> result = VitalAccountController.getOpposingPartiesForSelectdMatter(testMatterId);
        Test.stopTest();
        System.assertNotEquals(null, result, 'Should return a list');
    }
    private static Id createTestAccountForUser() {
        Account testAccount = new Account(Name = 'Test Account');
        insert testAccount;
        // Optional: If getCurrentUserAccountId() relies on a custom User field like AccountId__c
        User currentUser = [SELECT Id FROM User WHERE Id = :UserInfo.getUserId()];
        currentUser.put('AccountId__c', testAccount.Id); // Replace with actual logic if needed
        update currentUser;

        return testAccount.Id;
    }
    @isTest static void testGetOpposingPartiesDetails() {
        Id testAccountId = [SELECT Id FROM Account LIMIT 1].Id;

        Test.startTest();
        Account accDetails = VitalAccountController.getOpposingPartiesDetails(testAccountId);
        Test.stopTest();

        System.assertNotEquals(null, accDetails, 'Should return account details');
    }
    @IsTest
    static void testUpdateMatterDateTime(){
            Account acc = [SELECT Id, FirstName, LastName FROM Account LIMIT 1];
            MFL_Office__c mflOffice = [SELECT Id FROM MFL_Office__c Where Name = 'Test'];
            Matters__c matter =[select name, client_name__c, status__c, MFL_Office__c, Hire_Date__c from Matters__c where name='Test Matter'][0];
            matter=VitalAccountController.updateMatterDateTime(matter);
            System.assert(matter.Opened_in_Portal__c!=null);
    }
    @IsTest
    static void testGetPortalVideos(){
        List <Portal_Video__mdt> videos=VitalAccountController.getPortalVideos();
        system.assert(videos.size()>0);
    }
    @IsTest
    static void testGetAccountDetails() {
        User thisUser = [SELECT Id FROM User WHERE Id = :UserInfo.getUserId()]; 
        Account acc;
        system.runAs(thisUser)        { 
            Matters__c matter =[select name, client_name__c, status__c, MFL_Office__c, Hire_Date__c from Matters__c where name='Test Matter'][0];            
            PortalUserCreationUtility.AccountUserInfoClass Info= new PortalUserCreationUtility.AccountUserInfoClass();
            Info.AccountId=Matter.Client_Name__c;
            Info.theUser=null;
            Info.profileName='Customer Community User';
            List<PortalUserCreationUtility.AccountUserInfoClass> Infos= new List <PortalUserCreationUtility.AccountUserInfoClass>{Info};
            List<String> users=PortalUserCreationUtility.createPortalUser(Infos);
            system.debug('***users:  '+users);
        }
        User activeUser=[select id, isActive, IsPortalEnabled, AccountId__c from User where email='test@test.com']; /* Don get the user that we just created as he will be linked to an account */
        System.runAs(activeUser){ 
            Test.startTest();
                VitalAccountController.VitalWrapper wrapper = VitalAccountController.getAccountDetails();
            Test.stopTest();
            Id accId = VitalAccountController.getCurrentUserAccountId();            
            System.assert(wrapper.acc?.Id!=null);
            System.assertEquals(accId, wrapper.acc.Id);
        }
    }    
}