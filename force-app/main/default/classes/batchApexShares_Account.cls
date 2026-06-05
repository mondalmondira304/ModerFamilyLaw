public class batchApexShares_Account implements Database.Batchable<sObject>{
    public String query;
    public  id userIDfromTrigger;

    public Database.querylocator start(Database.BatchableContext BC){
        return Database.getQueryLocator(query);
    }

    public void execute(Database.BatchableContext BC, List<Account> scope){
        List<AccountShare> listToInsert = new List<AccountShare>();
        
        for(Account acctLoop : scope){
            AccountShare share = new AccountShare();
                share.UserOrGroupId = userIDfromTrigger;
                share.AccountId = acctLoop.Id;                       
                share.AccountAccessLevel = 'Edit';
                share.OpportunityAccessLevel = 'None';
                share.RowCause = 'Manual';
                listToInsert.add(share);
        }
        
        if(!listToInsert.isEmpty()){
            database.insert(listToInsert, false);
        }
    }  

    public void finish(Database.BatchableContext BC){
    }   
}