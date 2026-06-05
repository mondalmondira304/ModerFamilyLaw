trigger TaxesTrigger on Taxes__c (before insert, before update) {
    if (Trigger.isInsert || Trigger.isUpdate) {
        if (Trigger.isBefore) {
            TaxesHandler.checkMatterId(Trigger.new);
        }
    }
}