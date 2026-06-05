trigger OtherIncomeTrigger on Other_Income__c (before insert, before update) {
    if (Trigger.isInsert || Trigger.isUpdate) {
        if (Trigger.isBefore) {
            OtherIncomeHandler.checkMatterId(Trigger.new);
        }
    }
}