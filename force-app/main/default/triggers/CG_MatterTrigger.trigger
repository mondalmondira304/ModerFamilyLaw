trigger CG_MatterTrigger on Matters__c (before insert, after insert, after update, before update) {

    // Auto_Date_Change_Config__c config = Auto_Date_Change_Config__c.getOrgDefaults();

    // if(config.Active__c){
    //     Map<Id, String> matterFieldMap = new Map<Id, String>();

    //     CG_TaskDateUpdateHandler.handleMatterUpdate(Trigger.new, Trigger.oldMap);
    // }
    //TODO: Update trigger so that it checks the dates that would be updated. Send a set of matter ids
    //where on of the tracked dates was updated.

    if(Trigger.isInsert){
        if(Trigger.isAfter){
            MattersTriggerHandler.execute();
        }        
    }
    
    if(Trigger.isUpdate){
        Set<Id> idSet = new Set<Id>();

        for(Matters__c m : Trigger.New) {
            idSet.add(m.Id);
        }
    
        if(idSet.size() > 0) {
            CG_TaskDateUpdateHandler.handleMatterUpdateNew(idSet);
        }
    }   

    // August 2022 Update
    // Update Matter Child Objects with Primary Attorney and Paralegal User lookup
    if ((Trigger.isInsert || Trigger.isUpdate)
        && Trigger.isAfter) {
            MattersTriggerHandler.checkPrimaryUserFields(Trigger.new);
        }
}