trigger VehicleTrigger on Vehicle__c (before insert, before update) {
    if (Trigger.isInsert || Trigger.isUpdate) {
        if (Trigger.isBefore) {
            VehicleHandler.checkMatterId(Trigger.new);
        }
    }
}