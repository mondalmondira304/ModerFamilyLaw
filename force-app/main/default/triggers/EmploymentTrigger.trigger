trigger EmploymentTrigger on Employment__c (before insert, before update) {
    if (Trigger.isInsert || Trigger.isUpdate) {
        if (Trigger.isBefore) {
            EmploymentHandler.checkMatterId(Trigger.new);
        }
    }
}