@isTest
public class MatterControllerTest {

    @testSetup
    static void setupData() {
        // Create test Account
        User thisUser = [SELECT Id FROM User WHERE Id = :UserInfo.getUserId()];
        Account acc;
        System.runAs (thisUser) {  //use System.runAs() to avoid mixed DML errors        
            acc = new Account(Name = 'Test Account');
            UserRole r = [SELECT Id, Name, DeveloperName, ParentRoleId FROM UserRole where name like '%Attorney%' LIMIT 1];
            insert acc;
            // Create test User and assign AccountId
            Profile p = [SELECT Id FROM Profile WHERE Name = 'Standard User' LIMIT 1];
            User u = new User(
                FirstName = 'Test',
                LastName = 'User',
                Email = 'testuser@example.com',
                Username = 'testuser@example.com.' + System.currentTimeMillis(),
                Alias = 'tusr',
                TimeZoneSidKey = 'America/Los_Angeles',
                LocaleSidKey = 'en_US',
                EmailEncodingKey = 'UTF-8',
                LanguageLocaleKey = 'en_US',
                ProfileId = p.Id,
                UserRoleId = r.id
                //AccountId = acc.Id
            );
            insert u;
        }
            MFL_Office__c mflOffice = new MFL_Office__c(
                Name = 'Test'
            );
            insert mflOffice;       
            // Create test Matter linked to the Account and User
            List<Matters__c> matters = new List<Matters__c>();
            Matters__c matter1 = new Matters__c(
                Account__c = acc.Id,
                Client_Name__c = acc.Id,
                Status__c = 'Open',
                Matter_ID_Client__c = 'M-001',
                Case_Type__c = 'Adoption',
                MFL_Office__c = mflOffice.Id,
                Hire_Date__c = system.date.today()
            );
            matters.add(matter1);
            Matters__c matter2 = new Matters__c(
                Account__c = acc.Id,
                Client_Name__c = acc.Id,
                Status__c = 'Open',
                Matter_ID_Client__c = 'M-002',
                Case_Type__c = 'Adoption',
                MFL_Office__c = mflOffice.Id,
                Hire_Date__c = system.date.today()                
            );
            matters.add(matter2);
            insert matters;
        
    }
    @isTest
    static void testGetCurrentUserAccountId() {
        Account acc = [select id from account limit 1];
        MatterController.testAccountId = acc.Id;
        Test.startTest();
            Id accId = MatterController.getCurrentUserAccountId();
            System.assertNotEquals(null, accId, 'Account Id should not be null');
        Test.stopTest();
    }
    @isTest
    static void testGetCurrentUserDetail() {
        Account acc = [select id from account limit 1];
        MatterController.testAccountId = acc.Id;
        Test.startTest();
            acc = MatterController.getCurrentUserDetail();
            //System.assertNotEquals(null, acc.Id, 'Account Id should not be null');
        Test.stopTest();
    }    
    /*
    @isTest static void testGetMatterDetailsForCurrentUser() {
        Account acc = new Account(Name = 'Test Account');
        insert acc;
        MFL_Office__c mflOffice = new MFL_Office__c(Name = 'Test');
        insert mflOffice;
        Matters__c matter = new Matters__c(
            Account__c = acc.Id,
            Client_Name__c = acc.Id,
            Status__c = 'Open',
            Matter_ID_Client__c = 'M-001',
            Case_Type__c = 'Adoption',
            MFL_Office__c = mflOffice.Id
        );
        insert matter;
        MatterController.testAccountId = acc.Id;
        Test.startTest();
        Matters__c result = MatterController.getMatterDetailsForCurrentUser();
        Test.stopTest();
        System.assertNotEquals(null, result);
        System.assertEquals(matter.Id, result.Id);
    } */

    @isTest
    static void testGetMatterDetailsForPortalUser() {
        Account acc = new Account(Name = 'Test Account');
        insert acc;
        MFL_Office__c mflOffice = new MFL_Office__c(Name = 'Test');
        insert mflOffice;
        Matters__c matter = new Matters__c(
            Account__c = acc.Id,
            Client_Name__c = acc.Id,
            Status__c = 'Open',
            Matter_ID_Client__c = 'M-004',
            Case_Type__c = 'Adoption',
            MFL_Office__c = mflOffice.Id,
            Hire_Date__c = system.date.today()   
        );
        insert matter;
        MatterController.testAccountId = acc.Id;
        Test.startTest();
            Matters__c result = MatterController.getMatterDetailsForPortalUser();
        Test.stopTest();
        System.assertNotEquals(null, result, 'Matter should be returned for portal user');
    }
    @isTest
    static void GetMatterDetailsForPortalUserException() {
        try {
            MatterController.throwError=true;
            Matters__c result = MatterController.getMatterDetailsForPortalUser();
        } catch (Exception e) {        
            List<errorLog__c> errors=[select id from errorlog__c];
            system.assertEquals(2,errors.size());
        }
    }    
    @isTest
    static void testGetAllMatterDetailsForPortalUser() {
        Account acc = new Account(Name = 'Test Account');
        insert acc;
        MFL_Office__c mflOffice = new MFL_Office__c(Name = 'Test');
        insert mflOffice;        
        Matters__c matter = new Matters__c(
            Account__c = acc.Id,
            Client_Name__c = acc.Id,
            Status__c = 'Open',
            Matter_ID_Client__c = 'M-005',
            Case_Type__c = 'Adoption',
            MFL_Office__c = mflOffice.Id,
            Hire_Date__c = system.date.today()   
        );
        insert matter;
        MatterController.testAccountId = acc.Id;
        Test.startTest();
            List<Matters__c> result = MatterController.getAllMatterDetailsForPortalUser();
        Test.stopTest();
        System.assert(result.size() >= 1, 'Should return at least one Matter');
    }
    @isTest
    static void GetAllMatterDetailsForPortalUserException() {
        try {
            MatterController.throwError=true;
            List<Matters__c> result = MatterController.getAllMatterDetailsForPortalUser();
        } catch (Exception e) {        
            List<errorLog__c> errors=[select id from errorlog__c];
            system.assertEquals(2,errors.size());
        }
    }    
    @isTest
    static void testGetMatterDetailsForSelectedPortalUser() {
        Account acc = new Account(Name = 'Test Account');
        insert acc;
        MFL_Office__c mflOffice = new MFL_Office__c(Name = 'Test');
        insert mflOffice;        
        Matters__c matter = new Matters__c(
            Account__c = acc.Id,
            Client_Name__c = acc.Id,
            Status__c = 'Open',
            Matter_ID_Client__c = 'M-006',
            Case_Type__c = 'Adoption',
            MFL_Office__c = mflOffice.Id,
            Hire_Date__c = system.date.today()   
        );
        insert matter;
        MatterController.testAccountId = acc.Id;        
        Test.startTest();
            Matters__c result = MatterController.getMatterDetailsForSelectedPortalUser(matter.Id);
        Test.stopTest();
    }
    @isTest
    static void GetMatterDetailsForSelectedPortalUserException() {
        try {
            MatterController.throwError=true;
            Matters__c matter=[select id from Matters__c limit 1];
            Matters__c result = MatterController.getMatterDetailsForSelectedPortalUser(matter.Id);
        } catch (Exception e) {        
            List<errorLog__c> errors=[select id from errorlog__c];
            system.assertEquals(2,errors.size());
        }        
    }    
    @isTest 
    static void testUpdateMatters(){
        Account acc = new Account(Name = 'Test Account');
        insert acc;
        MFL_Office__c mflOffice = new MFL_Office__c(Name = 'Test');
        insert mflOffice;        
        Matters__c matter = new Matters__c(
            Account__c = acc.Id,
            Client_Name__c = acc.Id,
            Status__c = 'Open',
            Matter_ID_Client__c = 'M-005',
            Case_Type__c = 'Adoption',
            MFL_Office__c = mflOffice.Id,
            Hire_Date__c = system.date.today()   
        );
        insert matter;
        MatterController.testAccountId = acc.Id;
        Id matterId = matter.Id;
        Date expectedDate = System.Date.today();        
        matter.Retaining_Client_Date__c=expectedDate;
        matter.Retaining_Client_Decision__c='Stay with current attorney';
        matter.Retaining_Client_Signature__c='Signature';
        Test.startTest();
            Matters__c matterOut=MatterController.updateMatter(matter);
        Test.stopTest();
        System.assertEquals(expectedDate, matterOut.Retaining_Client_Date__c);
        System.assertEquals('Stay with current attorney', matterOut.Retaining_Client_Decision__c);
        System.assertEquals('Signature', matterOut.Retaining_Client_Signature__c);
    }

}