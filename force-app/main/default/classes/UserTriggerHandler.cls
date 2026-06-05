public inherited sharing class UserTriggerHandler {
    //need to add access for all of the accounts regardless of if they are linked to a matter
    //todo:
    //Create batch inserts for Users in the Attorney/Paralegal profile for existing Accounts and Matters. 
    //Update Matter trigger to only insert shares for matter records after insert for all users in Attorney/Paralegal Profile
    //Add Account trigger to insert shares for account records after insert for all users in the Attorney/Paralegal Profile
    public static Boolean doNotRunSharingLogic=false;
    
    public static void runUserTriggerLogic(){        
        if (UserTriggerHandler.doNotRunSharingLogic){ //to prevent too many SOQL queries when running certain tests
            return;
        }
        if(trigger.isAfter && trigger.isInsert){
            Profile profileId = [SELECT Id FROM Profile WHERE Name = 'Attorney/Paralegal' LIMIT 1];
            
            for(User u : (List<User>)Trigger.new){
                if(u.ProfileId == profileId.id){   
                    //Matter share creation for new user for every matter     
                    try{
                        batchApexShares_Matter bShares_matters = new batchApexShares_Matter();
                        bShares_matters.query = 'SELECT id,Client_Name__c,Opposing_Party_a__c FROM Matters__c';
                        bShares_matters.userIdFromTrigger = u.Id;
                        database.executeBatch(bShares_matters);
                    }catch(exception e) {
                        Utility.createFutureErrorRecord(e.getMessage(), e.getStackTraceString(), e.getLineNumber(), e.getTypeName(), 'UserTriggerHandler.runUserTriggerLogic(MattersNew)');    
                    }       
                    //Account share creation for new user for every account
                    try{
                        batchApexShares_Account bShares_acct = new batchApexShares_Account();
                        bShares_acct.query = 'SELECT Id FROM ACCOUNT';
                        bShares_acct.userIDfromTrigger = u.Id;
                        database.executeBatch(bShares_acct);       
                    }catch(exception e) {
                        Utility.createFutureErrorRecord(e.getMessage(), e.getStackTraceString(), e.getLineNumber(), e.getTypeName(), 'UserTriggerHandler.runUserTriggerLogic(AccountsNew)');    
                    }                  
                }
            }
        }
        
        //Added update context to share the records in update context when user activated back
        if(trigger.isAfter && trigger.isUpdate){
            
            Profile profileRec = [SELECT Id FROM Profile WHERE Name = 'Attorney/Paralegal' LIMIT 1];
            
            Map<id,user> oldMap = new Map<id,user>();
            
            for(string uid : trigger.oldMap.keyset()){
                oldMap.put(uid,(user)trigger.oldMap.get(uid));
            }
            
            for(User u : (List<User>)Trigger.new){
                if(u.ProfileId == profileRec.id && u.IsActive && (u.IsActive != oldMap.get(u.Id).isActive || u.ProfileId != oldMap.get(u.Id).ProfileId)){               
                    //Matter share creation for new user for every matter 
                    try{
                        batchApexShares_Matter bShares_matters = new batchApexShares_Matter();
                        bShares_matters.query = 'SELECT id,Client_Name__c,Opposing_Party_a__c FROM Matters__c';
                        bShares_matters.userIdFromTrigger = u.Id;
                        database.executeBatch(bShares_matters);   
                    }catch(exception e) {
                        Utility.createFutureErrorRecord(e.getMessage(), e.getStackTraceString(), e.getLineNumber(), e.getTypeName(), 'UserTriggerHandler.runUserTriggerLogic(MattersChange)');    
                    } 
                    
                    //account share creation for new user for every account
                    try{
                        batchApexShares_Account bShares_acct = new batchApexShares_Account();
                        bShares_acct.query = 'SELECT Id FROM ACCOUNT';
                        bShares_acct.userIDfromTrigger = u.Id;
                        database.executeBatch(bShares_acct);    
                    }catch(exception e) {
                        Utility.createFutureErrorRecord(e.getMessage(), e.getStackTraceString(), e.getLineNumber(), e.getTypeName(), 'UserTriggerHandler.runUserTriggerLogic(AccountsChange)');    
                    }                     
                }
            }
        }
        
    }    
}