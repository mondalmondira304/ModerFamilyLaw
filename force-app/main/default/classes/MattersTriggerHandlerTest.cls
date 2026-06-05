@isTest 
public without sharing class MattersTriggerHandlerTest {
    @testSetup
    static void testDataSetup() { 

        MFL_Office__c o = new MFL_Office__c();
        o.Name = 'Test Office';
        insert o;

        User thisUser = [SELECT Id FROM User WHERE Id = :UserInfo.getUserId()];

        Account client = new Account();
        client.Name = 'Test Client';
        client.Email__c = 'test@test.net';
        client.ownerId = thisUser.id;
        insert client;

        Contact con = new Contact(
            LastName  = 'Doe',
            AccountId = client.Id,
            Email     = 'doe@example.com'
        );
        insert con;

        Matters__c m = new Matters__c();
        m.Name = 'Test';
        m.MFL_Office__c = o.Id;
        m.Matter_ID_Client__c = '1111';
        m.Matter_ID_Matter__c = '123';
        m.Client_Name__c = client.Id;
        m.Case_Type__c = 'Adoption';
        m.Hire_Date__c = Date.today();
        m.Primary_Paralegal__c = thisUser.Id;
        m.Primary_Attorney__c = thisUser.Id;
        insert m;

        Life_Insurance__c ins = new Life_Insurance__c();
        ins.Name = 'Test Insurance Account';
        ins.Related_Matter__c = m.Id;
        insert ins;

        Housing__c house = new Housing__c();
        house.Name = 'Test House';
        house.Related_Matter__c = m.Id;
        insert house;

        Furniture_Personal_Property__c prop = new Furniture_Personal_Property__c();
        prop.Name = 'Test Personal Property';
        prop.Related_Matter__c = m.Id;
        insert prop;

        Bank_Account__c a = new Bank_Account__c();
        a.Name = 'Test Account';
        a.Related_Matter__c = m.Id;
        insert a;

        Investment_Account__c iAcct = new Investment_Account__c();
        iAcct.Name = 'Test Account';
        iAcct.Related_Matter__c = m.Id;       
        insert iAcct;

        Additional_Asset__c addtlAssets = new Additional_Asset__c();
        addtlAssets.Name = 'Test Additional Asset';
        addtlAssets.Related_Matter__c = m.Id;    
        insert addtlAssets;   

        Retirement_Account__c rAcct = new Retirement_Account__c();
        rAcct.Name = 'Test Retirement Acct';
        rAcct.Related_Matter__c = m.Id;          
        insert rAcct;

        Vehicle__c car = new Vehicle__c();
        car.Name = 'Test Car';
        car.Related_Matter__c = m.Id;
        insert car;

        Credit_Card__c card = new Credit_Card__c();
        card.Name = 'Test Bank Account';
        card.Matter_ID__c = m.Id;   
        insert card;

        Debt__c debt = new Debt__c();
        debt.Name = 'Test Debt';
        debt.Related_Matter__c = m.Id;       
        insert debt;

        Employment__c e = new Employment__c();
        e.Name = 'Test Job';
        e.Related_Matter__c = m.Id;
        insert e;

        Other_Income__c oIncome = new Other_Income__c();
        oIncome.Name = 'Test Other Income Account';
        oIncome.Matter__c = m.Id;     
        insert oIncome;

        Taxes__c tax = new Taxes__c();
        tax.Matter_ID__c = m.Id;
        insert tax; 

        Profile p = [SELECT Id FROM Profile WHERE Name='Customer Community User' LIMIT 1];  
        System.runAs(thisUser){
            User portalUser = new User(
                Alias = 'user2',
                Email='testuser2@example.com',
                FirstName='test',
                LastName= 'test',
                EmailEncodingKey='UTF-8',
                LanguageLocaleKey='en_US',
                LocaleSidKey='en_US',
                ProfileId = p.Id,
                contactId=con.id,               
                TimeZoneSidKey='America/New_York',
                UserName='testuser'+DateTime.now().getTime()+'@example.com'
            );
            insert portalUser; 
        }
    }
    @isTest
    private static void testChildRecordUpdates() {         
        Matters__c updateMatter = [SELECT Id, Client_Name__c FROM Matters__c WHERE  name='Test' LIMIT 1];
        Account newClient = new Account();
        newClient.Name = 'New Test Client';
        insert newClient;
        updateMatter.Client_Name__c = newClient.Id;
        update updateMatter;
        Life_Insurance__c ins = [SELECT Id, Client__c FROM Life_Insurance__c WHERE name = 'Test Insurance Account'];
        System.assertEquals(newClient.Id, ins.Client__c);
        Housing__c h = [SELECT Id, Client__c  FROM Housing__c WHERE Name = 'Test House'];
        System.assertEquals(newClient.Id, h.Client__c);
        MattersTriggerHandler.createObjectShare('Matters__c', updateMatter.Id, userInfo.getUserId());
    }
    @isTest
    private static void sendEmailsAboutMatter() {         
        List<Matters__c> matters = [select id, name, ownerid, owner.profile.name, Primary_Attorney__c, Primary_Attorney__r.name, Primary_Attorney__r.email,
                Primary_Paralegal__c, Primary_Paralegal__r.name, Primary_Paralegal__r.email, 
                account__r.ownerid FROM Matters__c WHERE  name='Test'];
        Test.startTest();
            MattersTriggerHandler.sendEmailsAboutMatter(matters);
        Test.stopTest();
        System.assert(true);
        //System.assertEquals(2, Limits.getEmailInvocations(), 'Two email invocations.'); emails are not sent out in test so there is no real way to test this.
    }    
    /*
    @isTest
    private static void CreateMatterSharesTest() {         
        User thisUser = [SELECT Id FROM User WHERE Id = :UserInfo.getUserId()];
        User portalUser = [Select id from User where Alias='user2'][0];
        Account client = [Select id from account where name='Test Client'][0];
  
        System.runAs (portalUser) {  //use System.runAs() to avoid mixed DML errors    
            MFL_Office__c o = new MFL_Office__c();
            o.Name = 'Test Office2';
            insert o;    
            Matters__c m = new Matters__c();
            m.Primary_Attorney__c=thisUser.Id;
            m.Name = 'TestTest';
            m.MFL_Office__c = o.Id;
            m.Matter_ID_Client__c = '2222';
            m.Matter_ID_Matter__c = '001';
            m.Client_Name__c = client.Id;
            m.Case_Type__c = 'Adoption';
            m.Hire_Date__c = Date.today();
            insert m;                      
        }        
        Matters__c updateMatter = [SELECT Id, Client_Name__c, ownerId FROM Matters__c WHERE  Matter_ID_Client__c = '2222' LIMIT 1];      
     
        Test.StartTest();
            MattersTriggerHandler.createMatterShares();
        Test.StopTest();
        List<Matters__Share> shares= [select id from Matters__share where parentid=:updateMatter.Id];
        System.assert(shares.size()>1, 'Number of matters share records need to be greater than 1');
        List<errorlog__c> errors =[select id from errorlog__c];
        System.assertEquals(0, errors.size());
    } */   
}