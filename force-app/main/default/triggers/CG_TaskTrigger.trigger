trigger CG_TaskTrigger on Task (after insert) {

    Set<Id> idSet = new Set<Id>();

    Auto_Date_Change_Config__c config = Auto_Date_Change_Config__c.getOrgDefaults();

    if(config.Active__c) {
        //add to trigger if linked field is in custom setting fields
        for(Task t : Trigger.New) {
            //Check if the Linked Field is not empty and Linked Field is in the custom setting field

            if(t.Linked_Date__c != null &&
               ((config.Tracked_Fields_1__c != null && config.Tracked_Fields_1__c.contains(t.Linked_Date__c)) || 
               (config.Tracked_Fields_2__c != null && config.Tracked_Fields_2__c.contains(t.Linked_Date__c)) || 
               (config.Tracked_Fields_3__c != null && config.Tracked_Fields_3__c.contains(t.Linked_Date__c)))) {

                idSet.add(t.id);
            }
        }

        if(idSet.size() != null) {
            CG_TaskDateUpdateHandler.verifyDueDate(idSet);
        }
    }
}