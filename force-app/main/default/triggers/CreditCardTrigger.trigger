trigger CreditCardTrigger on Credit_Card__c (before insert, before update) {
    if (Trigger.isInsert || Trigger.isUpdate) {
        if (Trigger.isBefore) {
            CreditCardHandler.checkMatterId(Trigger.new);
        }
    }
}