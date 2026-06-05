public inherited sharing class revokePermissionsController {
    public Matters__c record {get; private set;}
    //public String c {get;set;}
    //public String revoked{get;set;}
    String[] users = new String[]{};
    String[] revokedUsers = new String[]{};
        
    public revokePermissionsController(ApexPages.StandardController controller) {
        string id = ApexPages.currentPage().getParameters().get('id');
        record = [Select id, Name,Client_Name__c, Opposing_Party_a__c FROM Matters__c WHERE id =: id Limit 1];
    }  

    /*public revokePermissionsController(){
        string id = ApexPages.currentPage().getParameters().get('id');
        record = [Select id, Name,Client_Name__c FROM Matters__c WHERE id =: id Limit 1];
    }*/

    public String[] getUsers() {return users;}
    public void setUsers(String[] users) {this.users = users;}
    public String[] getRevokedUsers(){return revokedUsers;}
    public void setRevokedUsers(String[] revokedUsers) {this.revokedUsers = revokedUsers;}
   
   public List<SelectOption> getItems() {      
       List<SelectOption> options = new List<SelectOption>();
       Set<Id> userIds = new Set<Id>();
       for(User u:  [SELECT Id,name FROM USER WHERE isActive = true AND Profile.Name = 'Attorney/Paralegal']){
           userIds.add(u.Id);
       }
       
       Map<Id,Matters__Share> shareMap = new Map<Id,Matters__share>();
       for(Matters__Share mshare : [select ParentId,UserOrGroupId from Matters__share where ParentId=:record.Id and UserOrGroupId IN:userIds]){
           shareMap.put(mshare.UserOrGroupId,mshare);
       }
       
       for(User u : [SELECT Id,Name FROM USER WHERE Id IN:userIds]){
            if(shareMap.containsKey(u.Id)){
                options.add(new SelectOption(u.Name, u.Name));
            }           
        }
        
        return options;
    }

    public List<SelectOption> getRevokedItems(){
        List<SelectOption> options = new List<SelectOption>();
        Set<Id> userIds = new Set<Id>();
       for(User u:  [SELECT Id,name FROM USER WHERE isActive = true AND Profile.Name = 'Attorney/Paralegal']){
           userIds.add(u.Id);
       }
        
       Map<Id,Matters__Share> shareMap = new Map<Id,Matters__share>();
       for(Matters__Share mshare : [select ParentId,UserOrGroupId from Matters__share where ParentId=:record.Id and UserOrGroupId IN:userIds]){
           shareMap.put(mshare.UserOrGroupId,mshare);
       }
       
        for(User u : [SELECT Id,Name FROM USER WHERE Id IN:userIds])    {
            
            if(!shareMap.containsKey(u.Id)){
                options.add(new SelectOption(u.Name, u.Name));
            }           
        }
        
        return options;
    }      
    
    public Pagereference revokePermissions(){
        Set<Id> userSet = new Set<Id>();
        Map<String,User> userMap = new Map<String,User>();
        for(User u : [Select id, Name from User where Name IN:users]){
            userMap.put(u.Name,u);
        }
        
        for(String u : getUsers()){
            if(userMap.containsKey(u)){
                userSet.add(userMap.get(u).Id);
            }
        }
        DeleteFromSharesMatter(userSet, record.Id);
        if(record.Client_Name__c != null && record.Opposing_Party_a__c == null){
            DeleteFromSharesAccount(userSet, record.Client_Name__c);
        }
        if(record.Opposing_Party_a__c != null && record.Client_Name__C != null){
            DeleteFromSharesAccount(userSet, record.Client_Name__c, record.Opposing_Party_a__c);
        }
        
        return null; 
    }
    
    public pagereference grantPermissions(){
        Set<Id> userSet = new Set<Id>();
        Map<String,User> userMap = new Map<String,User>();
        for(User u : [Select id, Name from User where Name IN:revokedUsers]){
            userMap.put(u.Name,u);
        }
        for(String u : getRevokedUsers()){
            if(userMap.containsKey(u)){
                userSet.add(userMap.get(u).Id);
            }
        }
        
        for(Id u : userSet){
            MattersTriggerHandler.createObjectShare('Matters__c', record.Id, u);
        }         
        
        return null;      
    }
    
    public Pagereference backToRecord(){
        PageReference pg = new PageReference('/'+record.Id);
        pg.setRedirect(true);
        return pg;
    }

    @future
    public static void DeleteFromSharesMatter(Set<Id> userIds, Id Matter_ID){
        List<Matters__Share>  mShareList = new List<Matters__Share>([SELECT id, UserOrGroupId, AccessLevel, Parent.Name, Parent.RecordType.Name FROM Matters__Share WHERE UserOrGroupId in: userIds AND ParentId =: Matter_ID]);
        List<Revoke_Audit__c> raList = new List<Revoke_Audit__c>();

        //create Revoke Audit records for tracking which sharing records were removed
        if(!mShareList.isEmpty()){
            for(Matters__Share ms : mShareList){
                Revoke_Audit__c ra = new Revoke_Audit__c();
                ra.Name__c = ms.Parent.Name;
                ra.User__c = ms.UserOrGroupId;
                ra.Object__c = 'Matter';
                ra.Record_Id__c = ms.ParentId;
                ra.Record_Type__c = ms.Parent.RecordType.Name;
                raList.add(ra);
            }
            try{
                delete mShareList;

                if(!raList.isEmpty()){
                    database.insert(raList, false);//insert revoke audit records
                }
            }catch(exception e) {
                Utility.createErrorRecord(e.getMessage(), e.getStackTraceString(), e.getLineNumber(), e.getTypeName(), 'revokePermissionsController.DeleteFromSharesMatter');    
            }  
        }
    }

    @future
    public static void DeleteFromSharesAccount(Set<Id> userIds, Id PrimaryAccountId){
        List<AccountShare>  shareList = new List<AccountShare>([SELECT id, UserOrGroupId, AccountAccessLevel, Account.Name, Account.RecordType.Name  FROM AccountShare WHERE UserOrGroupId in: userIds AND AccountId =: PrimaryAccountId]);
        List<Revoke_Audit__c> raList = new List<Revoke_Audit__c>();

        //create Revoke Audit records for tracking which sharing records were removed
        if(!shareList.isEmpty()){
            for(AccountShare ash : shareList){
                Revoke_Audit__c ra = new Revoke_Audit__c();
                ra.Name__c = ash.Account.Name;
                ra.User__c = ash.UserOrGroupId;
                ra.Object__c = 'Account';
                ra.Record_Id__c = ash.AccountId;
                ra.Record_Type__c = ash.Account.RecordType.Name;
                raList.add(ra);
            }
            try{
                delete shareList;

                if(!raList.isEmpty()){
                    database.insert(raList, false);//insert revoke audit records
                }
            }catch(exception e) {
                Utility.createErrorRecord(e.getMessage(), e.getStackTraceString(), e.getLineNumber(), e.getTypeName(), 'revokePermissionsController.DeleteFromSharesAccount');    
            } 
        }
    }
    //Overloaded
    @future
    public static void DeleteFromSharesAccount(Set<Id> userIds, Id PrimaryAccountId, Id OpposingPartyAccountID){
        List<AccountShare>  shareList = new List<AccountShare>([SELECT id, UserOrGroupId, AccountAccessLevel, Account.Name , Account.RecordType.Name FROM AccountShare WHERE UserOrGroupId in: userIds AND (AccountId =: PrimaryAccountId OR AccountId =: OpposingPartyAccountID)]);
        List<Revoke_Audit__c> raList = new List<Revoke_Audit__c>();

        //create Revoke Audit records for tracking which sharing records were removed
        if(!shareList.isEmpty()){
            for(AccountShare ash : shareList){
                Revoke_Audit__c ra = new Revoke_Audit__c();
                ra.Name__c = ash.Account.Name;
                ra.User__c = ash.UserOrGroupId;
                ra.Object__c = 'Account';
                ra.Record_Id__c = ash.AccountId;
                ra.Record_Type__c = ash.Account.RecordType.Name;
                raList.add(ra);
            }
            try{
                delete shareList;

                if(!raList.isEmpty()){
                    database.insert(raList, false);//insert revoke audit records
                }
            }catch(exception e) {
                Utility.createErrorRecord(e.getMessage(), e.getStackTraceString(), e.getLineNumber(), e.getTypeName(), 'revokePermissionsController.DeleteFromSharesAccount(overloaded)');    
            } 
        }
    }
}