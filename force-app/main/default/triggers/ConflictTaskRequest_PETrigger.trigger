trigger ConflictTaskRequest_PETrigger on Conflict_Task_Request__e (after insert) {
    List<Task> toInsert = new List<Task>();

    for (Conflict_Task_Request__e evt : Trigger.New) {
        if (String.isBlank(evt.OwnerId__c) || String.isBlank(evt.RelatedToId__c)) continue;

        Task t = new Task();
        t.OwnerId      = (Id)evt.OwnerId__c;       
        t.WhatId       = (Id)evt.RelatedToId__c;   
        t.Subject      = String.isBlank(evt.Subject__c)  ? 'Conflict Check – Attorney (PC Hired)' : evt.Subject__c;
        t.Status       = String.isBlank(evt.Status__c)   ? 'Open'   : evt.Status__c;
        t.Priority     = String.isBlank(evt.Priority__c) ? 'High'   : evt.Priority__c;
        t.ActivityDate = (evt.DueDateOnly__c == null)    ? Date.today() : evt.DueDateOnly__c;

        if (!String.isBlank(evt.WhoId__c)) {
            t.WhoId = (Id)evt.WhoId__c;            
        }
        toInsert.add(t);
    }

    if (!toInsert.isEmpty()) {
        Database.DMLOptions dmo = new Database.DMLOptions();
        dmo.EmailHeader.triggerUserEmail = false;   // <-- force native assignment email
        Database.insert(toInsert, dmo);
    }
}