public class batchApexShares_AccountList implements Database.Batchable<sObject>{
    public String query;
    public List<User> userList;
 
    public Database.querylocator start(Database.BatchableContext BC){
       return Database.getQueryLocator(query);
    }
 
    public void execute(Database.BatchableContext BC, List<Account> scope){
       List<AccountShare> listToInsert = new List<AccountShare>();
 
       for(Account acctLoop : scope){
           for(User userIDLoop : userList){
                AccountShare share = new AccountShare();
                share.UserOrGroupId = userIDLoop.id;
                share.AccountId = acctLoop.Id;                       
                share.AccountAccessLevel = 'Edit';
                share.OpportunityAccessLevel = 'None';
                share.RowCause = 'Manual';
                listToInsert.add(share);
           }          
       }                
 
       if(!listToInsert.isEmpty()){
          database.insert(listToInsert, false);
       }
    }  
 
    public void finish(Database.BatchableContext BC){
    }
   //  batchApexShares_AccountList bShares_acct = new batchApexShares_AccountList();
   //  bShares_acct.query = 'SELECT Id FROM ACCOUNT';
   //  bShares_acct.userList = [SELECT ID FROM User WHERE isActive = true AND Profile.Name = 'Attorney/Paralegal'];
   //  database.executeBatch(bShares_acct);  
 }