@IsTest
private class TimeSolvZeroBalanceNotifiServiceTest {

    private static final String TASK_SUBJECT = 'Zero Trust Balance Client Notification';

    /**
     * @description Returns the Person Account record type Id.
     * @return Person Account record type Id.
     */
    private static Id getPersonAccountRecordTypeId() {
        return [
            SELECT Id
            FROM RecordType
            WHERE SObjectType = 'Account'
              AND IsPersonType = true
            LIMIT 1
        ].Id;
    }

    /**
     * @description Creates a Person Account for testing.
     * @param email PersonEmail value.
     * @param attorneyId Responsible Attorney Id.
     * @return Inserted and re-queried Account.
     */
    private static Account createPersonAccount(String email, Id attorneyId) {
        Account acc = new Account(
            RecordTypeId = getPersonAccountRecordTypeId(),
            LastName = 'Zero Balance Test ' + String.valueOf(Math.random()),
            PersonEmail = email,
            Responsible_Attorney__c = attorneyId,
            Timesolv_TrustAccount_Balance__c = 0,
            Timesolv_TrustAccount_Replenish_Below__c = 100,
            Timesolv_TrustAccount_Replenish_To__c = 500
        );
        insert acc;

        return [
            SELECT Id,
                   PersonContactId,
                   PersonEmail,
                   Responsible_Attorney__c,
                   Timesolv_TrustAccount_Balance__c,
                   Timesolv_TrustAccount_Replenish_Below__c,
                   Timesolv_TrustAccount_Replenish_To__c
            FROM Account
            WHERE Id = :acc.Id
        ];
    }

    /**
     * @description Inserts an existing suppression task for the Account.
     * @param acc Account.
     * @return Inserted Task.
     */
    private static Task createSuppressionTask(Account acc) {
        Task t = new Task(
            Subject = TASK_SUBJECT,
            WhatId = acc.Id,
            WhoId = acc.PersonContactId,
            OwnerId = acc.Responsible_Attorney__c,
            Status = 'Completed',
            Priority = 'Normal',
            ActivityDate = Date.today(),
            Description = 'Zero balance notice sent'
        );
        insert t;
        return t;
    }

    /**
     * @description Applies standard test config and email overrides.
     */
    private static void setupOverrides() {
        TimeSolvZeroBalanceConfig.setTestConfig(
            50,
            7,
            TASK_SUBJECT,
            'reception@modernfamilylaw.com',
            'First_Template',
            'Second_Template',
            'Modern Family Law CC Authorization'
        );
    }

    /**
     * @description Clears all static test overrides.
     */
    private static void clearOverrides() {
        TimeSolvZeroBalanceConfig.clearTestConfig();
        TimeSolvZeroBalanceEmailService.clearTestOverrides();
        TimeSolvIntegrationLogUtil.clearPendingLogs();
    }

    @IsTest
    static void testFirstReminderCreatesSuppressionTask() {
        setupOverrides();

        Id attorneyId = UserInfo.getUserId();
        Account acc = createPersonAccount('first.reminder@test.com', attorneyId);

        TimeSolvZeroBalanceEmailService.setTestConfiguration(true, new List<String>());
        TimeSolvZeroBalanceEmailService.setTestEmailOutcomes(
            new List<TimeSolvZeroBalanceEmailService.EmailOutcome>{
                new TimeSolvZeroBalanceEmailService.EmailOutcome(
                    new TimeSolvZeroBalanceEmailService.NotificationWorkItem(
                        acc.Id,
                        acc.PersonContactId,
                        acc.Responsible_Attorney__c,
                        TimeSolvZeroBalanceEmailService.ReminderType.FIRST
                    ),
                    true,
                    null
                )
            }
        );

        Test.startTest();
        TimeSolvZeroBalanceRepository repo = new TimeSolvZeroBalanceRepository();
        TimeSolvZeroBalanceEmailService emailSvc =
            new TimeSolvZeroBalanceEmailService(TimeSolvZeroBalanceConfig.getActive(), repo);
        TimeSolvZeroBalanceNotificationService svc =
            new TimeSolvZeroBalanceNotificationService(TimeSolvZeroBalanceConfig.getActive(), repo, emailSvc);

        svc.process(new List<Account>{ acc });
        TimeSolvIntegrationLogUtil.savePendingLogs();
        Test.stopTest();

        Task createdTask = [
            SELECT Subject, WhatId, WhoId, OwnerId, Status, Priority, ActivityDate, Description
            FROM Task
            WHERE WhatId = :acc.Id
              AND Subject = :TASK_SUBJECT
            LIMIT 1
        ];

        System.assertEquals(TASK_SUBJECT, createdTask.Subject);
        System.assertEquals(acc.Id, createdTask.WhatId);
        System.assertEquals(acc.PersonContactId, createdTask.WhoId);
        System.assertEquals(acc.Responsible_Attorney__c, createdTask.OwnerId);
        System.assertEquals('Completed', createdTask.Status);
        System.assertEquals('Normal', createdTask.Priority);
        System.assertEquals(Date.today(), createdTask.ActivityDate);
        System.assertEquals('Zero balance notice sent', createdTask.Description);

        clearOverrides();
    }

    @IsTest
    static void testSecondReminderDoesNotSendBeforeInterval() {
        setupOverrides();

        Id attorneyId = UserInfo.getUserId();
        Account acc = createPersonAccount('waiting.interval@test.com', attorneyId);
        createSuppressionTask(acc);

        TimeSolvZeroBalanceEmailService.setTestConfiguration(true, new List<String>());

        Test.startTest();
        TimeSolvZeroBalanceRepository repo = new TimeSolvZeroBalanceRepository();
        TimeSolvZeroBalanceEmailService emailSvc =
            new TimeSolvZeroBalanceEmailService(TimeSolvZeroBalanceConfig.getActive(), repo);
        TimeSolvZeroBalanceNotificationService svc =
            new TimeSolvZeroBalanceNotificationService(TimeSolvZeroBalanceConfig.getActive(), repo, emailSvc);

        svc.process(new List<Account>{ acc });
        TimeSolvIntegrationLogUtil.savePendingLogs();
        Test.stopTest();

        Integer taskCount = [
            SELECT COUNT()
            FROM Task
            WHERE WhatId = :acc.Id
              AND Subject = :TASK_SUBJECT
        ];
        System.assertEquals(1, taskCount);

        clearOverrides();
    }

    @IsTest
    static void testSecondReminderCreatesTaskAfterInterval() {
        setupOverrides();

        Id attorneyId = UserInfo.getUserId();
        Account acc = createPersonAccount('second.reminder@test.com', attorneyId);
        Task oldTask = createSuppressionTask(acc);
        Test.setCreatedDate(oldTask.Id, System.now().addDays(-8));

        TimeSolvZeroBalanceEmailService.setTestConfiguration(true, new List<String>());
        TimeSolvZeroBalanceEmailService.setTestEmailOutcomes(
            new List<TimeSolvZeroBalanceEmailService.EmailOutcome>{
                new TimeSolvZeroBalanceEmailService.EmailOutcome(
                    new TimeSolvZeroBalanceEmailService.NotificationWorkItem(
                        acc.Id,
                        acc.PersonContactId,
                        acc.Responsible_Attorney__c,
                        TimeSolvZeroBalanceEmailService.ReminderType.SECOND
                    ),
                    true,
                    null
                )
            }
        );

        Test.startTest();
        TimeSolvZeroBalanceRepository repo = new TimeSolvZeroBalanceRepository();
        TimeSolvZeroBalanceEmailService emailSvc =
            new TimeSolvZeroBalanceEmailService(TimeSolvZeroBalanceConfig.getActive(), repo);
        TimeSolvZeroBalanceNotificationService svc =
            new TimeSolvZeroBalanceNotificationService(TimeSolvZeroBalanceConfig.getActive(), repo, emailSvc);

        svc.process(new List<Account>{ acc });
        TimeSolvIntegrationLogUtil.savePendingLogs();
        Test.stopTest();

        Integer taskCount = [
            SELECT COUNT()
            FROM Task
            WHERE WhatId = :acc.Id
              AND Subject = :TASK_SUBJECT
        ];
        System.assertEquals(2, taskCount);

        clearOverrides();
    }

    @IsTest
    static void testEmptyScopeDoesNothing() {
        setupOverrides();
        Test.startTest();
        TimeSolvZeroBalanceRepository repo = new TimeSolvZeroBalanceRepository();
        TimeSolvZeroBalanceEmailService emailSvc =
            new TimeSolvZeroBalanceEmailService(TimeSolvZeroBalanceConfig.getActive(), repo);
        TimeSolvZeroBalanceNotificationService svc =
            new TimeSolvZeroBalanceNotificationService(TimeSolvZeroBalanceConfig.getActive(), repo, emailSvc);
        svc.process(new List<Account>());
        svc.process(null);
        Test.stopTest();
        clearOverrides();
    }

    @IsTest
    static void testCompleteEligibilitySkipsAccount() {
        setupOverrides();
        Id attorneyId = UserInfo.getUserId();
        Account acc = createPersonAccount('complete@test.com', attorneyId);
        createSuppressionTask(acc);
        createSuppressionTask(acc);

        TimeSolvZeroBalanceEmailService.setTestConfiguration(true, new List<String>());

        Test.startTest();
        TimeSolvZeroBalanceRepository repo = new TimeSolvZeroBalanceRepository();
        TimeSolvZeroBalanceEmailService emailSvc =
            new TimeSolvZeroBalanceEmailService(TimeSolvZeroBalanceConfig.getActive(), repo);
        TimeSolvZeroBalanceNotificationService svc =
            new TimeSolvZeroBalanceNotificationService(TimeSolvZeroBalanceConfig.getActive(), repo, emailSvc);
        svc.process(new List<Account>{ acc });
        Test.stopTest();

        Integer taskCount = [SELECT COUNT() FROM Task WHERE WhatId = :acc.Id AND Subject = :TASK_SUBJECT];
        System.assertEquals(2, taskCount, 'No new task should be created when already complete.');
        clearOverrides();
    }

    @IsTest
    static void testMissingEmailCreatesWarningLog() {
        setupOverrides();

        Id attorneyId = UserInfo.getUserId();
        Account acc = createPersonAccount(null, attorneyId);

        Test.startTest();
        TimeSolvZeroBalanceRepository repo = new TimeSolvZeroBalanceRepository();
        TimeSolvZeroBalanceEmailService emailSvc =
            new TimeSolvZeroBalanceEmailService(TimeSolvZeroBalanceConfig.getActive(), repo);
        TimeSolvZeroBalanceNotificationService svc =
            new TimeSolvZeroBalanceNotificationService(TimeSolvZeroBalanceConfig.getActive(), repo, emailSvc);

        svc.process(new List<Account>{ acc });
        TimeSolvIntegrationLogUtil.savePendingLogs();
        Test.stopTest();

        TimeSolv_Integration_Log__c logRow = [
            SELECT Type__c, Integration_Type__c, Message__c
            FROM TimeSolv_Integration_Log__c
            WHERE Account__c = :acc.Id
            ORDER BY CreatedDate DESC
            LIMIT 1
        ];

        System.assertEquals('Warning', logRow.Type__c);
        System.assertEquals('Zero Trust Balance', logRow.Integration_Type__c);
        System.assert(logRow.Message__c.contains('missing PersonContactId or PersonEmail'));

        clearOverrides();
    }

    @IsTest
    static void testNullAttorneyLogsWarning() {
        setupOverrides();
        Account acc = new Account(RecordTypeId = getPersonAccountRecordTypeId(), LastName = 'No Atty',
            PersonEmail = 'noatty@test.com', Timesolv_TrustAccount_Balance__c = 0,
            Timesolv_TrustAccount_Replenish_Below__c = 100, Timesolv_TrustAccount_Replenish_To__c = 500);
        insert acc;
        acc = [SELECT Id, PersonContactId, PersonEmail, Responsible_Attorney__c,
               Timesolv_TrustAccount_Balance__c, Timesolv_TrustAccount_Replenish_Below__c,
               Timesolv_TrustAccount_Replenish_To__c FROM Account WHERE Id = :acc.Id];
        Test.startTest();
        TimeSolvZeroBalanceRepository repo = new TimeSolvZeroBalanceRepository();
        TimeSolvZeroBalanceEmailService emailSvc = new TimeSolvZeroBalanceEmailService(TimeSolvZeroBalanceConfig.getActive(), repo);
        new TimeSolvZeroBalanceNotificationService(TimeSolvZeroBalanceConfig.getActive(), repo, emailSvc)
            .process(new List<Account>{ acc });
        TimeSolvIntegrationLogUtil.savePendingLogs();
        Test.stopTest();
        System.assert([SELECT Message__c FROM TimeSolv_Integration_Log__c WHERE Account__c = :acc.Id LIMIT 1]
            .Message__c.contains('Responsible Attorney'));
        clearOverrides();
    }

    @IsTest
    static void testEmailNotConfiguredLogsError() {
        setupOverrides();
        Account acc = createPersonAccount('nocfg@test.com', UserInfo.getUserId());
        TimeSolvZeroBalanceEmailService.setTestConfiguration(false, new List<String>{ 'OWE missing' });
        Test.startTest();
        TimeSolvZeroBalanceRepository repo = new TimeSolvZeroBalanceRepository();
        TimeSolvZeroBalanceEmailService emailSvc = new TimeSolvZeroBalanceEmailService(TimeSolvZeroBalanceConfig.getActive(), repo);
        new TimeSolvZeroBalanceNotificationService(TimeSolvZeroBalanceConfig.getActive(), repo, emailSvc)
            .process(new List<Account>{ acc });
        TimeSolvIntegrationLogUtil.savePendingLogs();
        Test.stopTest();
        System.assert([SELECT Message__c FROM TimeSolv_Integration_Log__c WHERE Account__c = :acc.Id LIMIT 1]
            .Message__c.contains('OWE missing'));
        clearOverrides();
    }

    @IsTest
    static void testFailedEmailLogsError() {
        setupOverrides();
        Account acc = createPersonAccount('fail@test.com', UserInfo.getUserId());
        TimeSolvZeroBalanceEmailService.setTestConfiguration(true, new List<String>());
        TimeSolvZeroBalanceEmailService.setTestEmailOutcomes(new List<TimeSolvZeroBalanceEmailService.EmailOutcome>{
            new TimeSolvZeroBalanceEmailService.EmailOutcome(
                new TimeSolvZeroBalanceEmailService.NotificationWorkItem(
                    acc.Id, acc.PersonContactId, acc.Responsible_Attorney__c,
                    TimeSolvZeroBalanceEmailService.ReminderType.FIRST), false, 'Send failed')
        });
        Test.startTest();
        TimeSolvZeroBalanceRepository repo = new TimeSolvZeroBalanceRepository();
        TimeSolvZeroBalanceEmailService emailSvc = new TimeSolvZeroBalanceEmailService(TimeSolvZeroBalanceConfig.getActive(), repo);
        new TimeSolvZeroBalanceNotificationService(TimeSolvZeroBalanceConfig.getActive(), repo, emailSvc)
            .process(new List<Account>{ acc });
        TimeSolvIntegrationLogUtil.savePendingLogs();
        Test.stopTest();
        System.assert([SELECT Message__c FROM TimeSolv_Integration_Log__c WHERE Account__c = :acc.Id LIMIT 1]
            .Message__c.contains('Send failed'));
        clearOverrides();
    }
}