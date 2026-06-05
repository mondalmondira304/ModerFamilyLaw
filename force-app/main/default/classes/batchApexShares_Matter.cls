public class batchApexShares_Matter implements Database.Batchable<sObject>{
   public String query;
   public Id userIdFromTrigger;

   public Database.querylocator start(Database.BatchableContext BC){
      return Database.getQueryLocator(query);
   }

   public void execute(Database.BatchableContext BC, List<Matters__c> scope){
      List<Matters__Share> mattersListToInsert = new List<Matters__Share>();

      for(Matters__c MattLoop : scope){
         Matters__Share  mShare = new Matters__Share();
         mShare.UserOrGroupId = userIdFromTrigger;
         mShare.ParentId = MattLoop.id;                       
         mShare.AccessLevel = 'Edit';
         mShare.RowCause = 'Manual';
         mattersListToInsert.add(mShare);
      }                

      if(!mattersListToInsert.isEmpty()){
         database.insert(mattersListToInsert, false);
      }
   }  

   public void finish(Database.BatchableContext BC){
   }
}