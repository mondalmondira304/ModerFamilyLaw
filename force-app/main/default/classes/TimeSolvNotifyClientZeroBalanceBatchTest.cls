@IsTest
private class TimeSolvNotifyClientZeroBalanceBatchTest {

    private static void cfg() {
        TimeSolvZeroBalanceConfig.setTestConfig(
            5, 7, 'Zero Trust Balance Client Notification',
            'reception@modernfamilylaw.com',
            'First_Template', 'Second_Template',
            'Modern Family Law CC Authorization'
        );
    }

    private static void resetAll() {
        TimeSolvZeroBalanceConfig.clearTestConfig();
        TimeSolvZeroBalanceEmailService.clearTestOverrides();
        TimeSolvIntegrationLogUtil.clearPendingLogs();
        timeSolvNotifyClientZeroBalanceBatch.TEST_THROW_EXECUTE_EXCEPTION = false;
        timeSolvNotifyClientZeroBalanceBatch.TEST_THROW_RUN_BATCH_EXCEPTION = false;
        timeSolvNotifyClientZeroBalanceBatch.TEST_THROW_START_EXCEPTION = false;
        TimeSolvNotifyClientZeroBalanceScheduler.TEST_THROW_SCHEDULER_EXCEPTION = false;
    }

    private static Account acc() {
        Id rtId = [
            SELECT Id
            FROM RecordType
            WHERE SObjectType = 'Account' AND IsPersonType = true
            LIMIT 1
        ].Id;

        Account a = new Account(
            RecordTypeId = rtId,
            LastName = 'PA ' + System.now().getTime(),
            PersonEmail = 'zero' + System.now().getTime() + '@test.com',
            Responsible_Attorney__c = UserInfo.getUserId(),
            Timesolv_TrustAccount_Balance__c = 0,
            Timesolv_TrustAccount_Replenish_Below__c = 100,
            Timesolv_TrustAccount_Replenish_To__c = 500
        );
        insert a;

        return [
            SELECT Id,
                   PersonContactId,
                   PersonEmail,
                   Responsible_Attorney__c,
                   Timesolv_TrustAccount_Balance__c,
                   Timesolv_TrustAccount_Replenish_Below__c,
                   Timesolv_TrustAccount_Replenish_To__c
            FROM Account
            WHERE Id = :a.Id
        ];
    }

    @IsTest
    static void testExecuteSuccessCreatesTask() {
        cfg();
        Account a = acc();

        TimeSolvZeroBalanceEmailService.setTestConfiguration(true, new List<String>());
        TimeSolvZeroBalanceEmailService.setTestEmailOutcomes(
            new List<TimeSolvZeroBalanceEmailService.EmailOutcome>{
                new TimeSolvZeroBalanceEmailService.EmailOutcome(
                    new TimeSolvZeroBalanceEmailService.NotificationWorkItem(
                        a.Id, a.PersonContactId, a.Responsible_Attorney__c,
                        TimeSolvZeroBalanceEmailService.ReminderType.FIRST
                    ),
                    true,
                    null
                )
            }
        );

        Test.startTest();
        new timeSolvNotifyClientZeroBalanceBatch().execute(null, new List<SObject>{ a });
        Test.stopTest();

        System.assertEquals(1, [
            SELECT COUNT()
            FROM Task
            WHERE WhatId = :a.Id
            AND Subject = 'Zero Trust Balance Client Notification'
        ]);
        resetAll();
    }

    @IsTest
    static void testExecuteFailureDoesNotCreateTask() {
        cfg();
        Account a = acc();

        TimeSolvZeroBalanceEmailService.setTestConfiguration(true, new List<String>());
        TimeSolvZeroBalanceEmailService.setTestEmailOutcomes(
            new List<TimeSolvZeroBalanceEmailService.EmailOutcome>{
                new TimeSolvZeroBalanceEmailService.EmailOutcome(
                    new TimeSolvZeroBalanceEmailService.NotificationWorkItem(
                        a.Id, a.PersonContactId, a.Responsible_Attorney__c,
                        TimeSolvZeroBalanceEmailService.ReminderType.FIRST
                    ),
                    false,
                    'Forced email failure'
                )
            }
        );

        Test.startTest();
        new timeSolvNotifyClientZeroBalanceBatch().execute(null, new List<SObject>{ a });
        Test.stopTest();

        System.assertEquals(0, [
            SELECT COUNT()
            FROM Task
            WHERE WhatId = :a.Id
            AND Subject = 'Zero Trust Balance Client Notification'
        ]);
        resetAll();
    }

    @IsTest
    static void testExecuteCatch() {
        cfg();
        Account a = acc();
        timeSolvNotifyClientZeroBalanceBatch.TEST_THROW_EXECUTE_EXCEPTION = true;

        Test.startTest();
        try {
            new timeSolvNotifyClientZeroBalanceBatch().execute(null, new List<SObject>{ a });
            System.assert(false, 'Expected forced batch execute exception');
        } catch (Exception e) {
            System.assert(e.getMessage().contains('Forced batch execute exception'));
        }
        Test.stopTest();

        resetAll();
    }

    @IsTest
    static void testStartEmptyFinish() {
        cfg();

        Test.startTest();
        Database.QueryLocator ql = new timeSolvNotifyClientZeroBalanceBatch().start(null);
        new timeSolvNotifyClientZeroBalanceBatch().execute(null, new List<SObject>());
        new timeSolvNotifyClientZeroBalanceBatch().finish(null);
        Test.stopTest();

        System.assertNotEquals(null, ql);
        resetAll();
    }

    @IsTest
    static void testRunBatchAndSchedulerSuccess() {
        cfg();
        acc();

        Test.startTest();
        Id batchId = timeSolvNotifyClientZeroBalanceBatch.runBatch(1);
        new TimeSolvNotifyClientZeroBalanceScheduler().execute(null);
        Test.stopTest();

        System.assertNotEquals(null, batchId);
        System.assert([SELECT COUNT() FROM AsyncApexJob WHERE JobType = 'BatchApex'] > 0);
        resetAll();
    }

    @IsTest
    static void testSchedulerCatch() {
        cfg();
        TimeSolvNotifyClientZeroBalanceScheduler.TEST_THROW_SCHEDULER_EXCEPTION = true;

        Test.startTest();
        try {
            new TimeSolvNotifyClientZeroBalanceScheduler().execute(null);
            System.assert(false, 'Expected forced scheduler exception');
        } catch (Exception e) {
            System.assert(e.getMessage().contains('Forced scheduler exception'));
        }
        Test.stopTest();

        resetAll();
    }
    
    @IsTest
static void testRunBatchDefaultBatchSize() {
    cfg();
    acc();
    Test.startTest();
    Id batchId = timeSolvNotifyClientZeroBalanceBatch.runBatch(null);
    Test.stopTest();
    System.assertNotEquals(null, batchId);
    resetAll();
}

@IsTest
static void testRunBatchCatch() {
    cfg();
    timeSolvNotifyClientZeroBalanceBatch.TEST_THROW_RUN_BATCH_EXCEPTION = true;
    Test.startTest();
    try {
        timeSolvNotifyClientZeroBalanceBatch.runBatch(1);
        System.assert(false, 'Expected exception');
    } catch (Exception e) {
        System.assert(e.getMessage().contains('Forced batch runBatch exception for test'));
    }
    Test.stopTest();
    resetAll();
}

@IsTest
static void testStartCatch() {
    cfg();
    timeSolvNotifyClientZeroBalanceBatch.TEST_THROW_START_EXCEPTION = true;
    Test.startTest();
    try {
        new timeSolvNotifyClientZeroBalanceBatch().start(null);
        System.assert(false, 'Expected exception');
    } catch (Exception e) {
        System.assert(e.getMessage().contains('Forced batch start exception for test'));
    }
    Test.stopTest();
    resetAll();
}
}