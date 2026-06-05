@isTest
public with sharing class TestDataFactory {
    public static Profile prof = [SELECT Id FROM Profile WHERE Name='Attorney/Paralegal'][0];
    public static Profile Operationsprof = [SELECT Id FROM Profile WHERE Name='Operations'][0];
    public static Profile Portalprof = [SELECT Id FROM Profile WHERE Name='Customer Community Plus User'][0];
    public static Id prsnAccountRecTypeId = Schema.SObjectType.Account.getRecordTypeInfosByDeveloperName().get('PersonAccount').getRecordTypeId();
    public static MFL_Office__c office;
    public static List<Account> personAccounts;
    public static User aUser;
    /*
    public static User getOperationsUser() {
        if (activeUser != null) {return activeUser;}
        activeUser = new User(Alias = 'Active', Email = 'ActiveUser1@testorg.com', EmailEncodingKey = 'UTF-8', LastName = 'ActiveTestingUser1',
                LanguageLocaleKey = 'en_US', LocaleSidKey = 'en_US', ProfileId = Operationsprof.Id, TimeZoneSidKey = 'America/Los_Angeles', UserName = 'ActiveUser1@modernfamilylaw.com', isActive = true);
        insert activeUser;
        return activeUser;
    }    
    public static User getActiveUser() {
        if (activeUser != null) {return activeUser;}
        activeUser = new User(Alias = 'Active', Email = 'ActiveUser1@testorg.com', EmailEncodingKey = 'UTF-8', LastName = 'ActiveTestingUser2',
                LanguageLocaleKey = 'en_US', LocaleSidKey = 'en_US', ProfileId = prof.Id, TimeZoneSidKey = 'America/Los_Angeles', UserName = 'ActiveUser1@modernfamilylaw.com', isActive = true);
        insert activeUser;
        return activeUser;
    }
    public static User getInactivePortalUser() {
        if (inactiveUser!=null)  {return inactiveUser;  }
        inactiveUser = new User(Alias = 'Inact', Email='InactiveUser1@testorg.com',EmailEncodingKey='UTF-8', LastName='InactiveTestingUser3',
                LanguageLocaleKey='en_US',LocaleSidKey='en_US', ProfileId = Portalprof.Id,TimeZoneSidKey='America/Los_Angeles', UserName='InactiveUser@modernfamilylaw.com',isActive=false);
        insert inactiveUser;
        return inactiveUser; 
    }
    */
    public static User getUser(){
        if (aUser!=null){
            return aUser;
        }
        Profile p = [SELECT Id FROM Profile WHERE Name='Attorney/Paralegal' LIMIT 1];           
        UserRole r = [SELECT Id, Name, DeveloperName, ParentRoleId FROM UserRole where name like '%Attorney%' LIMIT 1];
        User aUser = new User(
                Alias = 'user2',
                Email='testuser2@example.com',
                LastName= 'test',
                EmailEncodingKey='UTF-8',
                LanguageLocaleKey='en_US',
                LocaleSidKey='en_US',
                ProfileId = p.Id,
                UserRoleId=r.Id,                
                TimeZoneSidKey='America/New_York',
                UserName='testuser'+DateTime.now().getTime()+'@example.com'
            );
        insert aUser;
        return aUser;
    }
    @future
    public static void futureSetUpData() {  //setup data in a future method to prevent mixed DML operations       
        Matters__c oneMatter=getMatters(1)[0]; // will create one person account as well
    }
    public static List<Account> getPersonAccounts(Integer numOfAccounts){ //the default recordType is Client
        return   getPersonAccounts(numOfAccounts, 'Client');
    }
    public static List<Account> getPersonAccounts(Integer numOfAccounts, String recordTypeName){        
        //if (personAccounts!=null) return personAccounts;
        personAccounts= new List<Account>();
        Recordtype r = [Select Id From RecordType where sObjectType='Account' and name = :recordTypeName];	   
        Integer random=Integer.valueOf(Math.random() * 1000);     
        if (r==null){
            return null;
        }
        for(Integer i = 0; i < numOfAccounts; i++){
            personAccounts.add(
                new Account(
                RecordTypeId= r.Id,
                FirstName= 'Test FN-' + i +random,
                LastName='Test LN-' + i + random,
                PersonEmail= 'test-' + i + random + '@example.com',
                PersonMobilePhone='5101112222',
                Responsible_Attorney__c=getUser().Id,
                Responsible_Paralegal__c=getUser().Id ,
                Quoted_Retainer__c=10,
                Type_of_Case_A__c='Divorce w/Children')
            );
        }
        insert personAccounts;
        return personAccounts;
    }
    public static MFL_Office__c get_MFL_Office(){
        if (office!=null) return office;
        office = new MFL_Office__c(Name='Test Office');
        insert office;
        return office;
    }
    public static Matters__c getSingleMatter (String statusIn, Id accountId){ //return a single matter with a certain status and assigned to an account
        List<Matters__c> mattersList = new List<Matters__c>();
        Integer i=Integer.valueOf(Math.random() * 1000);
        Account opposingparty= new Account(RecordTypeId= prsnAccountRecTypeId, FirstName= 'Test FN-'+i,LastName='Test LN-'+i,PersonEmail= 'test-'+i +  '@example.com');
        insert opposingparty;
        mattersList.add(new Matters__c(Name = 'Test '+i, hire_date__c=System.Date.Today(),  Status__c=statusIn, Primary_Attorney__c=getUser().Id,
            MFL_Office__c = get_MFL_Office().Id, Client_Name__c=accountId, Opposing_Party_a__c=opposingparty.id, Matter_ID_Matter__c=i.format()) );    
        insert mattersList;
        return mattersList[0];
    }    
    public static List<Matters__c> getMatters (Integer numOfMatters, String status_in){
        List<Matters__c> mattersList = new List<Matters__c>();
        List<Account> accts=getPersonAccounts(numOfMatters);
        Account opposingparty= new Account(RecordTypeId= prsnAccountRecTypeId, FirstName= 'Test FN-',LastName='Test LN-',PersonEmail= 'test-' +  '@example.com');
        insert opposingparty;
        for (Integer i = 0; i<numOfMatters; i++){
            mattersList.add(new Matters__c(Name = 'Test '+i, hire_date__c=System.Date.Today(), Status__c=status_in, Primary_Attorney__c=getUser().Id,
                MFL_Office__c = get_MFL_Office().Id, Client_Name__c=accts[i].Id, Opposing_Party_a__c=opposingparty.id, Matter_ID_Matter__c=i.format()) );
        }
        insert mattersList;
        return mattersList;
    }
    public static List<Matters__c> getMatters(Integer numOfMatters){ //overloaded to handle the generic case
        return getMatters(numOfMatters, 'Open');
    }
}