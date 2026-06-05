trigger InvestmentAccountTrigger on Investment_Account__c (before insert, before update) {
    if (Trigger.isInsert || Trigger.isUpdate) {
        if (Trigger.isBefore) {
            InvestmentAccountHandler.checkMatterId(Trigger.new);
        }
    }
}