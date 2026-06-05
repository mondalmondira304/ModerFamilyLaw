@IsTest
private class ConflictTaskRequest_PETriggerTest {

    @IsTest
    static void testConflictTaskRequestCreatesTask() {
        
        Account acc = new Account(
            LastName = 'Test Account',
            RecordTypeId = [SELECT Id FROM RecordType WHERE SObjectType = 'Account' AND DeveloperName = 'PersonAccount' LIMIT 1].Id
        );
        insert acc;

        Contact con = new Contact(
    LastName = 'Tester',
    Email = 'tester@example.com'
);
insert con;

        User u = [SELECT Id FROM User WHERE IsActive = true LIMIT 1];

        Test.startTest();
        Conflict_Task_Request__e evt = new Conflict_Task_Request__e(
            OwnerId__c     = u.Id,
            RelatedToId__c = acc.Id,     
            WhoId__c       = con.Id,     
            Subject__c     = 'Test Conflict Task',
            Status__c      = 'Not Started',
            Priority__c    = 'Normal',
            DueDateOnly__c = Date.today().addDays(3)
        );
        Database.SaveResult sr = EventBus.publish(evt);
        Test.stopTest();

        System.assert(sr.isSuccess(), 'Platform event should publish successfully');

        Task created = [
            SELECT Id, OwnerId, WhatId, WhoId, Subject, Status, Priority, ActivityDate
            FROM Task
            WHERE WhatId = :acc.Id
            LIMIT 1
        ];

        System.assertEquals(u.Id, created.OwnerId);
        System.assertEquals(acc.Id, created.WhatId);
        System.assertEquals(con.Id, created.WhoId);
        System.assertEquals('Test Conflict Task', created.Subject);
        System.assertEquals('Not Started', created.Status);
        System.assertEquals('Normal', created.Priority);
        System.assertEquals(Date.today().addDays(3), created.ActivityDate);
    }

    @IsTest
    static void testConflictTaskRequestDefaults() {
        Account acc = new Account(
            LastName = 'Default Case',
            RecordTypeId = [SELECT Id FROM RecordType WHERE SObjectType = 'Account' AND DeveloperName = 'PersonAccount' LIMIT 1].Id
        );
        insert acc;

        User u = [SELECT Id FROM User WHERE IsActive = true LIMIT 1];

        Test.startTest();
        Conflict_Task_Request__e evt = new Conflict_Task_Request__e(
            OwnerId__c     = u.Id,
            RelatedToId__c = acc.Id
        );
        Database.SaveResult sr = EventBus.publish(evt);
        Test.stopTest();

        System.assert(sr.isSuccess(), 'Minimal platform event should publish successfully');

        Task created = [
            SELECT Subject, Status, Priority, ActivityDate
            FROM Task
            WHERE WhatId = :acc.Id
            LIMIT 1
        ];

        System.assertEquals('Conflict Check – Attorney (PC Hired)', created.Subject);
        System.assertEquals('Open', created.Status);
        System.assertEquals('High', created.Priority);
        System.assertEquals(Date.today(), created.ActivityDate);
    }
}