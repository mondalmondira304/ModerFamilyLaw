trigger LifeInsuranceTrigger on Life_Insurance__c (before insert, before update) {
    if (Trigger.isInsert || Trigger.isUpdate) {
        if (Trigger.isBefore) {
            LifeInsuranceTriggerHandler.checkMatterId(Trigger.new);
        }
    }
}