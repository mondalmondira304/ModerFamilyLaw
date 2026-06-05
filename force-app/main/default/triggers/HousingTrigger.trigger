trigger HousingTrigger on Housing__c (before insert, before update) {
    if (Trigger.isInsert || Trigger.isUpdate) {
        if (Trigger.isBefore) {
            HousingTriggerHandler.checkMatterId(Trigger.new);
        }
    }
}