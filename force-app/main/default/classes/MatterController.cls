public without sharing class MatterController {

    @TestVisible private static Id testAccountId;
    @TestVisible private static Account testAccount;    
    @TestVisible private static Boolean throwError=false;
    public class InvalidException extends Exception {}
    @AuraEnabled
    public static Matters__c getMatterDetailsForPortalUser() { //only gets one open matter associated with the Portal user--used to support the attorney transition logic
    try {
        if (throwError) {Decimal r=0/0;} //for testing of exception handling
        Id accountId = getCurrentUserAccountId();
        system.debug('AccountId: ' + accountId);
        // Query to fetch the Matter__c record related to the Account. 
        List<Matters__c> matterRecords = [SELECT Id, Client_Name__r.Id, Client_Name__r.Photo_URL__c, Matter_ID_Auto__c, Account__r.Name, Account__r.Photo_URL__c, 
            Matter_ID_Client__c, Matter_ID_Full__c, Matter_ID_Matter__c, Client_Name__r.Name, Primary_Paralegal__c,Primary_Paralegal__r.Name, Primary_Attorney__r.Name,
            Retaining_Client_Date__c, Retaining_Client_Decision__c, Retaining_Client_Signature__c
            FROM Matters__c WHERE Client_Name__r.Id = :accountId AND Status__c not in ('Closed', 'Refund Due') LIMIT 1];
        // If a record is found, return it; otherwise, return null
        if (!matterRecords.isEmpty()) {
            system.debug('Matter Record: ' + matterRecords[0]);
            return matterRecords[0];
        } else {
            system.debug('No Matter record found for the current user.');
            return null;
        }
        } catch(exception e) {
            Utility.createErrorRecord(e.getMessage(), e.getStackTraceString(), e.getLineNumber(), e.getTypeName(), 'MatterController.getMatterDetailsForPortalUser');                
            throw new AuraHandledException('Error getting matter details: ' + e.getMessage());
        }     
    }   
   /*@AuraEnabled
    public static Matters__c getMatterForAttorneyTransition() { //Gets the first matter that is flagged for attorney transition 
    try {
        if (throwError) {Decimal r=0/0;} //for testing of exception handling
        Id accountId = getCurrentUserAccountId();
        system.debug('AccountId: ' + accountId);
        // Query to fetch the Matter__c record related to the Account. 
        List<Matters__c> matterRecords = [SELECT Id, Client_Name__r.Id, Client_Name__r.Photo_URL__c, Matter_ID_Auto__c, Account__r.Name, Account__r.Photo_URL__c, 
            Matter_ID_Client__c, Matter_ID_Full__c, Matter_ID_Matter__c, Client_Name__r.Name, Primary_Paralegal__c,Primary_Paralegal__r.Name, Primary_Attorney__r.Name,
            Retaining_Client_Date__c, Retaining_Client_Decision__c, Retaining_Client_Signature__c 
            FROM Matters__c  WHERE Client_Name__r.Id = :accountId
            AND Status__c='Open' and (Retaining_Clients__c = True OR Not_Retaining_Clients__c = True ) LIMIT 1];
        // If a record is found, return it; otherwise, return null
        if (!matterRecords.isEmpty()) {
            system.debug('Matter Record: ' + matterRecords[0]);
            return matterRecords[0];
        } else {
            system.debug('No Matter record found for the current user.');
            return null;
        }
        } catch(exception e) {
            Utility.createErrorRecord(e.getMessage(), e.getStackTraceString(), e.getLineNumber(), e.getTypeName(), 'MatterController.getMatterDetailsForPortalUser');                
            throw new AuraHandledException('Error getting matter details: ' + e.getMessage());
        }     
    }*/      
    @AuraEnabled
    public static Matters__c updateMatter(Matters__c matterIn) { //to handle attorney transition logic--updates all open matters associated with an account
       try{
            Id accountId = getCurrentUserAccountId();        
            system.debug('matterIn:  '+matterIn);
            if (matterIn==null){
                throw new invalidException('No Matter was supplied');
            }
            else if (matterIn.Retaining_Client_Date__c==null || matterIn.Retaining_Client_Signature__c==null || matterIn.Retaining_Client_Decision__c==null){
                throw new invalidException('One or more of the retaining fields were not filled out.');
            }
            List<Matters__c> matterRecords = [SELECT Id, Retaining_Client_Date__c, Retaining_Client_Signature__c, Retaining_Client_Decision__c FROM Matters__c  WHERE Client_Name__r.Id = :accountId AND Status__c not in ('Closed', 'Refund Due')];
            //apply the same results to all the open matters associated with this client
            for (Matters__c matt: matterRecords){
                matt.Retaining_Client_Date__c=matterIn.Retaining_Client_Date__c;
                matt.Retaining_Client_Decision__c=matterIn.Retaining_Client_Decision__c;
                matt.Retaining_Client_Signature__c=matterIn.Retaining_Client_Signature__c;
            }
            update matterRecords;
            return matterRecords[0];  //just return one
        } catch(exception e) {
            Utility.createFutureErrorRecord(e.getMessage(), e.getStackTraceString(), e.getLineNumber(), e.getTypeName(), 'MatterController.updateMatter');    
            throw new AuraHandledException('Error updateAccount: ' + e.getMessage());
        }
    }    
    @AuraEnabled(cacheable=true)
    public static Id getCurrentUserAccountId() {
        if (Test.isRunningTest() && testAccountId != null) {
            return testAccountId;
        }
        User currentUser = [SELECT Id, AccountId FROM User WHERE Id = :UserInfo.getUserId()];
        system.debug('Current User: ' + currentUser);
        return currentUser.AccountId;
    }
    @AuraEnabled(cacheable=true)
    public static Account getCurrentUserDetail() {
        if (Test.isRunningTest() && testAccountId != null) {
            return testAccount;
        }
        User currentUser = [SELECT Id, AccountId FROM User WHERE Id = :UserInfo.getUserId()];
        Account acct=[select id, Name, firstName, lastName, PersonEmail, Responsible_Attorney__r.name, Responsible_Attorney__r.Hourly_Billing_Rate__c,Responsible_Paralegal__r.name,
            send_credit_request__c, Allow_Fee_Agreement__c, Fa_Portal_Signing_URL__c, Invoice_Retainer_URL__c, Timesolv_TrustAccount_Balance__c, FA_Portal_Agreement_Status__c,
            Total_Fee_Agreement_Amount__c, credit_check_complete__c, Credit_Applicant__c, Credit_Decision__c  from Account where id=:currentUser.AccountId];
        return acct;
    }
    @AuraEnabled
    public static List<Matters__c> getAllMatterDetailsForPortalUser() {
    try{
        if (throwError) {Decimal r=0/0;} //for testing of exception handling
        Id accountId = getCurrentUserAccountId();
        system.debug('AccountId: ' + accountId);
        List<Matters__c> matterRecords = [SELECT Id, Case_Type__c, Status__c, LastModifiedDate, Opposing_Party_a__r.Name, Client_Name__r.Id, Client_Name__r.Photo_URL__c, Matter_ID_Auto__c,
            Account__r.Name, Account__r.Photo_URL__c, Matter_ID_Client__c, Matter_ID_Full__c, Matter_ID_Matter__c, Client_Name__r.Name, Primary_Paralegal__c,Primary_Paralegal__r.Name, Primary_Attorney__r.Name,
            Primary_Attorney__r.Retaining_Clients__c, Primary_Attorney__r.Not_Retaining_Clients__c, Retaining_Client_Decision__c, Retaining_Client_Date__c, Retaining_Client_Signature__c
            FROM Matters__c  WHERE Client_Name__r.Id = :accountId AND Status__c not in ('Closed','Refund Due')];
        if (!matterRecords.isEmpty()) {
            system.debug('Matter Record: ' + matterRecords[0]);
            return matterRecords;
        } else {
            system.debug('No Matter record found for the current user.');
            return (new List<Matters__c>());            
        }
        } catch(exception e) {
            Utility.createErrorRecord(e.getMessage(), e.getStackTraceString(), e.getLineNumber(), e.getTypeName(), 'MatterController.getAllMatterDetailsForPortalUser');                
            throw new AuraHandledException('Error getting matter details: ' + e.getMessage());
        }         
    }
    @AuraEnabled
    public static Matters__c getMatterDetailsForSelectedPortalUser(String matterId) {
    try {
        if (throwError) {Decimal r=0/0;} //for testing of exception handling
        Id accountId = getCurrentUserAccountId();
        system.debug('AccountId: ' + accountId);
        List<Matters__c> matterRecords = [SELECT Id, Case_Type__c, Status__c, Opposing_Party_a__r.Name, Client_Name__r.Id, Client_Name__r.Photo_URL__c, Matter_ID_Auto__c, 
            Account__r.Name, Account__r.Photo_URL__c, Matter_ID_Client__c, Matter_ID_Full__c, Matter_ID_Matter__c, Client_Name__r.Name, Primary_Paralegal__c,Primary_Paralegal__r.Name, Primary_Attorney__r.Name 
            FROM Matters__c  WHERE Client_Name__r.Id = :accountId AND Status__c  not in ('Closed', 'Refund Due') AND Id = :matterId];
        if (!matterRecords.isEmpty()) {
            system.debug('Matter Record: ' + matterRecords[0]);
            return matterRecords[0];
        } else {
            system.debug('No Matter record found for the current user.');            
            return null;
        }
        } catch(exception e) {
            Utility.createErrorRecord(e.getMessage(), e.getStackTraceString(), e.getLineNumber(), e.getTypeName(), 'MatterController.getMatterDetailsForSelectedPortalUser');                
            throw new AuraHandledException('Error getting matter details: ' + e.getMessage());
        }           
    }   
  
}