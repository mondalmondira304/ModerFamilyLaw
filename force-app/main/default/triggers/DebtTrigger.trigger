trigger DebtTrigger on Debt__c (before insert, before update) {
    if (Trigger.isInsert || Trigger.isUpdate) {
        if (Trigger.isBefore) {
            DebtTriggerHandler.checkMatterId(Trigger.new);
        }
    }
}