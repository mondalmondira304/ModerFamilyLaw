public class batchApexShares implements Database.Batchable<sObject>{
	public String query;

    public Database.querylocator start(Database.BatchableContext BC){
                return Database.getQueryLocator(query);
    }

   public void execute(Database.BatchableContext BC, List<sObject> scope){
         List<User> uList = [SELECT ID, Name FROM User WHERE isActive=true and Profile.Name='Attorney/Paralegal'];
         List<Matters__Share> mattShare = new List<Matters__Share>();
         List<Matters__Share> matterShare = new List<Matters__Share>();
         List<AccountShare> acctShare = new List<AccountShare>();
         List<AccountShare> aShare = new List<AccountShare>();

         for(Matters__c m :(List<Matters__c>)scope){         
            if(m.Client_Name__c != null){
               AccountShare share = new AccountShare();
               share.AccountId = m.Client_Name__c;
               share.AccountAccessLevel = 'Edit';
               share.OpportunityAccessLevel = 'None';
               share.RowCause = 'Manual';
               acctShare.add(share);
            }
            
            Matters__Share  mShare = new Matters__Share();
            mShare.ParentId = m.Id;                       
            mShare.AccessLevel = 'Edit';
            mshare.RowCause = 'Manual';
            mattShare.add(mShare);       
         }

         //GIVEN a List of Matter Shares that have a matter id attached
         //WHEN  code block is executed
         //THEN  each user in target profile has matter shares created for them
         for(Matters__Share loopVar : mattShare){
            for(User u : uList){
                  Matters__Share userMatterShare = new Matters__Share();
                  userMatterShare.ParentID = loopVar.ParentID;
                  userMatterShare.AccessLevel = loopVar.AccessLevel;
                  userMatterShare.RowCause = loopVar.RowCause;
                  userMatterShare.UserOrGroupID = u.Id;
                  matterShare.add(userMatterShare);   
            }             
         }
         
         database.insert(matterShare, false);
   
         if(!acctShare.isEmpty()){
         for(AccountShare loopVar : acctShare){
            for(User u :uList){
                  AccountShare userAccountShare = new AccountShare();
                  userAccountShare.AccountId = loopVar.AccountId;
                  userAccountShare.AccountAccessLevel = loopVar.AccountAccessLevel;
                  userAccountShare.OpportunityAccessLevel = loopVar.OpportunityAccessLevel;
                  userAccountShare.RowCause = loopVar.RowCause;
                  userAccountShare.UserOrGroupID = u.id;
                  aShare.add(userAccountShare);
                  
            }
         }
         
         if(!aShare.isEmpty()){
            database.insert(aShare, false);
         }
      }
   }  

   public void finish(Database.BatchableContext BC){
	}
}