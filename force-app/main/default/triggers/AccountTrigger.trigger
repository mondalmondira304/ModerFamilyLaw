trigger AccountTrigger on Account (after insert, before insert, before update, after update) {
    if(Trigger.isInsert){
        if(Trigger.isAfter){
            AccountTriggerHandler.execute();
        }        
    }
    
    //Changes made for Fee Agreement
    if(trigger.isBefore){
        if(Trigger.isInsert){
            AccountTriggerHandler.updateEngagementStatusTime(trigger.new);
        }
        if(trigger.isUpdate){
            AccountTriggerHandler.updateEnagagementStatus(trigger.new,trigger.oldMap);
        }
    }
    


    if(trigger.isAfter && trigger.isUpdate){
        Trigger_Control__mdt triggerControl = Trigger_Control__mdt.getInstance('Account_Email_Change');
        if(triggerControl != null && triggerControl.Is_Enabled__c == true) {
            AccountTriggerHandler.accountEmailChange(trigger.new,trigger.oldMap);
        }
        
        //AccountTriggerHandler.createClientTimesolv(trigger.new,trigger.oldMap);
        //AccountTriggerHandler.createReportisoftpull(trigger.new,trigger.oldMap);
    }
}