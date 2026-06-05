public class batchApexShares_MatterList implements Database.Batchable<sObject>{
    public String query;
    public List<User> userList;
 
    public Database.querylocator start(Database.BatchableContext BC){
       return Database.getQueryLocator(query);
    }
 
    public void execute(Database.BatchableContext BC, List<Matters__c> scope){
       List<Matters__Share> mattersListToInsert = new List<Matters__Share>();
 
       for(Matters__c MattLoop : scope){
           for(User userIDLoop : userList){
            Matters__Share  mShare = new Matters__Share();
            mShare.UserOrGroupId = userIDLoop.id;
            mShare.ParentId = MattLoop.id;                       
            mShare.AccessLevel = 'Edit';
            mShare.RowCause = 'Manual';
            mattersListToInsert.add(mShare);
           }
          
       }                
 
       if(!mattersListToInsert.isEmpty()){
          database.insert(mattersListToInsert, false);
       }
    }  
 
    public void finish(Database.BatchableContext BC){
    }
    // batchApexShares_MatterList bShares_matters = new batchApexShares_MatterList();
    // bShares_matters.query = 'SELECT id,Client_Name__c,Opposing_Party_a__c FROM Matters__c';
    // bShares_matters.userList = [SELECT ID FROM User WHERE isActive = true AND Profile.Name = 'Attorney/Paralegal'];
    // database.executeBatch(bShares_matters);
 }