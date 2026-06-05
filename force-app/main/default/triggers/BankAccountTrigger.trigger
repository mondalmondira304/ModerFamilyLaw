trigger BankAccountTrigger on Bank_Account__c (before insert, before update) {
    if (Trigger.isInsert || Trigger.isUpdate) {
        if (Trigger.isBefore) {
            BankAccountTriggerHandler.checkMatterId(Trigger.new);
        }
    }
}