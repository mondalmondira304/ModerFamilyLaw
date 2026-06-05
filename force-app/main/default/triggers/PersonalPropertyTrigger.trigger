trigger PersonalPropertyTrigger on Furniture_Personal_Property__c (before insert, before update) {
    if (Trigger.isInsert || Trigger.isUpdate) {
        if (Trigger.isBefore) {
            PersonalPropTriggerHandler.checkMatterId(Trigger.new);
        }
    }
}