trigger RetirementAccountTrigger on Retirement_Account__c (before insert, before update) {
    if (Trigger.isInsert || Trigger.isUpdate) {
        if (Trigger.isBefore) {
            RetirementAccountHandler.checkMatterId(Trigger.new);
        }
    }
}