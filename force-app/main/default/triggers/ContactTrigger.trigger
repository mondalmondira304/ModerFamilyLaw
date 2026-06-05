trigger ContactTrigger on Contact(before insert, after insert){
    if(Trigger.isInsert){
        Trigger_Control__mdt triggerControl = Trigger_Control__mdt.getInstance('Contact_Trigger');
        if(triggerControl != null && triggerControl.Is_Enabled__c == true) {
            if(Trigger.isBefore){
                ContactTriggerHandler.createPersonAccountBefore(trigger.new);
            }    
            if(Trigger.isAfter){
                ContactTriggerHandler.createPersonAccountAfter(trigger.new);
            }
        }   
    }

}