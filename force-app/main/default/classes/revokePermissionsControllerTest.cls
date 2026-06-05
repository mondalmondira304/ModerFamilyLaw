@isTest
private class revokePermissionsControllerTest {
    
    @testSetup
    private static void doTestDataSetup(){
        UserRole testRole = new UserRole(DeveloperName = 'FTC_AttorneysTest', Name = 'FTC Attorneys');
        insert testRole;
    }
    static testMethod void testController() {
        // Create test data
        Profile profile = [SELECT Id FROM Profile WHERE Name = 'Attorney/Paralegal' LIMIT 1];
        Profile profileAdmin = [SELECT Id FROM Profile WHERE Name = 'System Administrator' LIMIT 1];
        //RecordType trainingRecId =  [SELECT Id FROM RecordType WHERE Name = 'Training' and SObjectType = 'Account'];
        List<UserRole> testRoles = new List<UserRole>([SELECT Id FROM UserRole WHERE DeveloperName = 'FTC_AttorneysTest' LIMIT 1]);
        User testUser1 = new User(Alias = 'testu1', Email='testuser123@exampleuser.com', 
                                  EmailEncodingKey='UTF-8', LastName='User1', 
                                  LanguageLocaleKey='en_US', LocaleSidKey='en_US', 
                                  ProfileId = profile.Id, TimeZoneSidKey='America/Los_Angeles', 
                                  UserName='testuser123@exampleuser.com', UserRoleId = testRoles[0].Id, IsActive = TRUE);
        insert testUser1;

        User testUser2 = new User(Alias = 'testu2', Email='testuser21@exampleuser.com', 
                                  EmailEncodingKey='UTF-8', LastName='User2', 
                                  LanguageLocaleKey='en_US', LocaleSidKey='en_US', 
                                  ProfileId = profile.Id, TimeZoneSidKey='America/Los_Angeles', 
                                  UserName='testuser21@exampleuser.com', UserRoleId = testRoles[0].Id, IsActive = TRUE);
        insert testUser2;

        User testUser3 = new User(Alias = 'testu2', Email='testuser21@exampleuser.com', 
                            EmailEncodingKey='UTF-8', LastName='User2', 
                            LanguageLocaleKey='en_US', LocaleSidKey='en_US', 
                            ProfileId = profile.Id, TimeZoneSidKey='America/Los_Angeles', 
                            UserName='testuser314@exampleuser.com', UserRoleId = testRoles[0].Id, IsActive = TRUE);
        insert testUser3;

        User testAdmin = new User(Alias = 'te1234', Email='testuse1234@exampleuser.com', 
                                  EmailEncodingKey='UTF-8', LastName='testuse1234', 
                                  LanguageLocaleKey='en_US', LocaleSidKey='en_US', 
                                  ProfileId = profileAdmin.Id, TimeZoneSidKey='America/Los_Angeles', 
                                  UserName='testuse1234@exampleuser.com', UserRoleId = testRoles[0].Id, IsActive = TRUE);
        insert testAdmin;        

        System.runAs(testAdmin){
            Account testAccount = new Account(Name = 'Test Account');
            insert testAccount;

            Account testAccount2 = new Account(Name = 'Test Account 2');
            insert testAccount2;
            
            MFL_Office__c mfo = new MFL_Office__c(name='test',state__c='test');
            insert mfo;

            Matters__c testMatter = new Matters__c(Name = 'Test Matter', Client_Name__c = testAccount.Id,MFL_Office__c=mfo.Id, Hire_Date__c = Date.today(),Case_Type__c = 'Adoption');
            insert testMatter;

            List<AccountShare> accShares = new List<AccountShare>();
            accShares = [SELECT Id FROM AccountShare WHERE UserOrGroupId = :testUser3.Id];
            if(!accShares.isEmpty()){
                delete accShares;
            }
            List<Matters__Share> matShares = new List<Matters__Share>();
            matShares = [SELECT Id FROM Matters__Share WHERE UserOrGroupId = :testUser3.Id];
            if(!matShares.isEmpty()){
                delete matShares;
            }

            // Setup page and controller
            Test.setCurrentPageReference(Page.revokePermissionsAccount); // Assuming SomePage is your VF page
            ApexPages.currentPage().getParameters().put('id', testMatter.Id);

            ApexPages.StandardController sc = new ApexPages.StandardController(testMatter);
            revokePermissionsController controller = new revokePermissionsController(sc);

            // Test getUsers and setUsers
            //List<User> usersList1 = [SELECT Id, Name FROM User WHERE Username = 'testuser123@exampleuser.com' LIMIT 1];
            //System.debug(usersList1[0].Name);
            String[] users = new String[]{};
            users.add('User1');
            controller.setUsers(users);

            // Test getRevokedUsers and setRevokedUsers
            String[] revokedUsers = new String[]{};
            revokedUsers.add('User2');
            controller.setRevokedUsers(revokedUsers);

            // Test getItems method
            List<SelectOption> items = controller.getItems();

            // Test getRevokedItems method
            List<SelectOption> revokedItems = controller.getRevokedItems();

            // Test revokePermissions method
            Test.startTest();

            
            controller.revokePermissions();

            controller.setRevokedUsers(revokedUsers);

            // Verify revokePermissions
            List<Matters__Share> shares = [SELECT Id FROM Matters__Share WHERE ParentId = :testMatter.Id AND UserOrGroupId = :testUser1.Id];

            // Test grantPermissions method

            controller.grantPermissions();
            Test.stopTest();

            // Verify grantPermissions
            shares = [SELECT Id FROM Matters__Share WHERE ParentId = :testMatter.Id AND UserOrGroupId = :testUser2.Id];

            // Test backToRecord method
            PageReference pr = controller.backToRecord();
        }
        
    }

    //Duplicate test method to add coverage for second DeleteFromSharesAccount method
    static testMethod void testController2() {
        // Create test data
        Profile profile = [SELECT Id FROM Profile WHERE Name = 'Attorney/Paralegal' LIMIT 1];
        Profile profileAdmin = [SELECT Id FROM Profile WHERE Name = 'System Administrator' LIMIT 1];
        //RecordType trainingRecId =  [SELECT Id FROM RecordType WHERE Name = 'Training' and SObjectType = 'Account'];
        List<UserRole> testRoles = new List<UserRole>([SELECT Id FROM UserRole WHERE DeveloperName = 'FTC_AttorneysTest' LIMIT 1]);
        User testUser1 = new User(Alias = 'testu1', Email='testuser123@exampleuser.com', 
                                  EmailEncodingKey='UTF-8', LastName='User1', 
                                  LanguageLocaleKey='en_US', LocaleSidKey='en_US', 
                                  ProfileId = profile.Id, TimeZoneSidKey='America/Los_Angeles', 
                                  UserName='testuser123@exampleuser.com', UserRoleId = testRoles[0].Id, IsActive = TRUE);
        insert testUser1;

        User testUser2 = new User(Alias = 'testu2', Email='testuser21@exampleuser.com', 
                                  EmailEncodingKey='UTF-8', LastName='User2', 
                                  LanguageLocaleKey='en_US', LocaleSidKey='en_US', 
                                  ProfileId = profile.Id, TimeZoneSidKey='America/Los_Angeles', 
                                  UserName='testuser21@exampleuser.com', UserRoleId = testRoles[0].Id, IsActive = TRUE);
        insert testUser2;

        User testUser3 = new User(Alias = 'testu2', Email='testuser21@exampleuser.com', 
                            EmailEncodingKey='UTF-8', LastName='User2', 
                            LanguageLocaleKey='en_US', LocaleSidKey='en_US', 
                            ProfileId = profile.Id, TimeZoneSidKey='America/Los_Angeles', 
                            UserName='testuser314@exampleuser.com', UserRoleId = testRoles[0].Id, IsActive = TRUE);
        insert testUser3;

        User testAdmin = new User(Alias = 'te1234', Email='testuse1234@exampleuser.com', 
                                  EmailEncodingKey='UTF-8', LastName='testuse1234', 
                                  LanguageLocaleKey='en_US', LocaleSidKey='en_US', 
                                  ProfileId = profileAdmin.Id, TimeZoneSidKey='America/Los_Angeles', 
                                  UserName='testuse1234@exampleuser.com', UserRoleId = testRoles[0].Id, IsActive = TRUE);
        insert testAdmin;        

        System.runAs(testAdmin){
            Account testAccount = new Account(Name = 'Test Account');
            insert testAccount;

            Account testAccount2 = new Account(Name = 'Test Account 2');
            insert testAccount2;
            
            MFL_Office__c mfo = new MFL_Office__c(name='test',state__c='test');
            insert mfo;

            Matters__c testMatter = new Matters__c(Name = 'Test Matter', Client_Name__c = testAccount.Id,MFL_Office__c=mfo.Id,Opposing_Party_a__c = testAccount2.Id, Hire_Date__c = Date.today(),Case_Type__c = 'Adoption');
            insert testMatter;

            List<AccountShare> accShares = new List<AccountShare>();
            accShares = [SELECT Id FROM AccountShare WHERE UserOrGroupId = :testUser3.Id];
            if(!accShares.isEmpty()){
                delete accShares;
            }
            List<Matters__Share> matShares = new List<Matters__Share>();
            matShares = [SELECT Id FROM Matters__Share WHERE UserOrGroupId = :testUser3.Id];
            if(!matShares.isEmpty()){
                delete matShares;
            }

            // Setup page and controller
            Test.setCurrentPageReference(Page.revokePermissionsAccount); // Assuming SomePage is your VF page
            ApexPages.currentPage().getParameters().put('id', testMatter.Id);

            ApexPages.StandardController sc = new ApexPages.StandardController(testMatter);
            revokePermissionsController controller = new revokePermissionsController(sc);

            // Test getUsers and setUsers
            //List<User> usersList1 = [SELECT Id, Name FROM User WHERE Username = 'testuser123@exampleuser.com' LIMIT 1];
            //System.debug(usersList1[0].Name);
            String[] users = new String[]{};
            users.add('User1');
            controller.setUsers(users);

            // Test getRevokedUsers and setRevokedUsers
            String[] revokedUsers = new String[]{};
            revokedUsers.add('User2');
            controller.setRevokedUsers(revokedUsers);

            // Test getItems method
            List<SelectOption> items = controller.getItems();

            // Test getRevokedItems method
            List<SelectOption> revokedItems = controller.getRevokedItems();

            // Test revokePermissions method
            Test.startTest();

            
            controller.revokePermissions();

            controller.setRevokedUsers(revokedUsers);

            // Verify revokePermissions
            List<Matters__Share> shares = [SELECT Id FROM Matters__Share WHERE ParentId = :testMatter.Id AND UserOrGroupId = :testUser1.Id];

            // Test grantPermissions method

            controller.grantPermissions();
            Test.stopTest();

            // Verify grantPermissions
            shares = [SELECT Id FROM Matters__Share WHERE ParentId = :testMatter.Id AND UserOrGroupId = :testUser2.Id];

            // Test backToRecord method
            PageReference pr = controller.backToRecord();
        }
    }
}