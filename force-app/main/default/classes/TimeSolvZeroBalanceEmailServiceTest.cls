@IsTest
private class TimeSolvZeroBalanceEmailServiceTest {

    private static TimeSolvZeroBalanceEmailService buildService() {
        TimeSolvZeroBalanceConfig.setTestConfig(50, 7, 'Test Subject', 'test@test.com',
            'First_Template', 'Second_Template', 'Excluded Prefix');
        TimeSolvZeroBalanceRepository repo = new TimeSolvZeroBalanceRepository();
        return new TimeSolvZeroBalanceEmailService(TimeSolvZeroBalanceConfig.getActive(), repo);
    }

    private static void cleanup() {
        TimeSolvZeroBalanceConfig.clearTestConfig();
        TimeSolvZeroBalanceEmailService.clearTestOverrides();
    }

    @IsTest
    static void testConstructorResolvesConfigErrors() {
        TimeSolvZeroBalanceEmailService svc = buildService();
        // Templates and OWE won't exist in test context so errors are expected
        System.assertEquals(false, svc.isConfigured());
        System.assert(!svc.getConfigurationErrors().isEmpty());
        cleanup();
    }

    @IsTest
    static void testSetTestConfigurationOverridesConfigured() {
        TimeSolvZeroBalanceEmailService svc = buildService();
        TimeSolvZeroBalanceEmailService.setTestConfiguration(true, new List<String>());
        System.assertEquals(true, svc.isConfigured());
        System.assert(svc.getConfigurationErrors().isEmpty());
        cleanup();
    }

    @IsTest
    static void testSetTestConfigurationNotConfigured() {
        TimeSolvZeroBalanceEmailService svc = buildService();
        TimeSolvZeroBalanceEmailService.setTestConfiguration(false, new List<String>{ 'Error A', 'Error B' });
        System.assertEquals(false, svc.isConfigured());
        System.assertEquals(2, svc.getConfigurationErrors().size());
        cleanup();
    }

    @IsTest
    static void testSetTestConfigurationNullErrors() {
        TimeSolvZeroBalanceEmailService svc = buildService();
        TimeSolvZeroBalanceEmailService.setTestConfiguration(true, null);
        System.assertEquals(true, svc.isConfigured());
        cleanup();
    }

    @IsTest
    static void testSendReturnsTestOutcomes() {
        TimeSolvZeroBalanceEmailService svc = buildService();
        TimeSolvZeroBalanceEmailService.NotificationWorkItem wi =
            new TimeSolvZeroBalanceEmailService.NotificationWorkItem(
                UserInfo.getUserId(), UserInfo.getUserId(), UserInfo.getUserId(),
                TimeSolvZeroBalanceEmailService.ReminderType.FIRST);
        TimeSolvZeroBalanceEmailService.setTestEmailOutcomes(
            new List<TimeSolvZeroBalanceEmailService.EmailOutcome>{
                new TimeSolvZeroBalanceEmailService.EmailOutcome(wi, true, null)
            });

        Test.startTest();
        List<TimeSolvZeroBalanceEmailService.EmailOutcome> results = svc.send(new List<TimeSolvZeroBalanceEmailService.NotificationWorkItem>{ wi });
        Test.stopTest();

        System.assertEquals(1, results.size());
        System.assertEquals(true, results[0].success);
        cleanup();
    }

    @IsTest
    static void testSendEmptyAndNullWorkItems() {
        TimeSolvZeroBalanceEmailService svc = buildService();
        TimeSolvZeroBalanceEmailService.clearTestOverrides();

        Test.startTest();
        System.assert(svc.send(new List<TimeSolvZeroBalanceEmailService.NotificationWorkItem>()).isEmpty());
        System.assert(svc.send(null).isEmpty());
        Test.stopTest();
        cleanup();
    }

    @IsTest
    static void testSetTestEmailOutcomesNull() {
        TimeSolvZeroBalanceEmailService.setTestEmailOutcomes(null);
        System.assertEquals(null, TimeSolvZeroBalanceEmailService.testEmailOutcomes);
        cleanup();
    }

    @IsTest
    static void testClearTestOverrides() {
        TimeSolvZeroBalanceEmailService.setTestConfiguration(true, new List<String>{ 'err' });
        TimeSolvZeroBalanceEmailService.setTestEmailOutcomes(
            new List<TimeSolvZeroBalanceEmailService.EmailOutcome>());
        TimeSolvZeroBalanceEmailService.clearTestOverrides();
        System.assertEquals(false, TimeSolvZeroBalanceEmailService.bypassSetupLookups);
        System.assertEquals(null, TimeSolvZeroBalanceEmailService.testConfigured);
        System.assertEquals(null, TimeSolvZeroBalanceEmailService.testConfigurationErrors);
        System.assertEquals(null, TimeSolvZeroBalanceEmailService.testEmailOutcomes);
    }

    @IsTest
    static void testNotificationWorkItemProperties() {
        TimeSolvZeroBalanceEmailService.NotificationWorkItem wi =
            new TimeSolvZeroBalanceEmailService.NotificationWorkItem(
                UserInfo.getUserId(), UserInfo.getUserId(), UserInfo.getUserId(),
                TimeSolvZeroBalanceEmailService.ReminderType.SECOND);
        System.assertEquals(UserInfo.getUserId(), wi.accountId);
        System.assertEquals(TimeSolvZeroBalanceEmailService.ReminderType.SECOND, wi.reminderType);
    }

    @IsTest
    static void testEmailOutcomeProperties() {
        TimeSolvZeroBalanceEmailService.NotificationWorkItem wi =
            new TimeSolvZeroBalanceEmailService.NotificationWorkItem(
                UserInfo.getUserId(), UserInfo.getUserId(), UserInfo.getUserId(),
                TimeSolvZeroBalanceEmailService.ReminderType.FIRST);
        TimeSolvZeroBalanceEmailService.EmailOutcome outcome =
            new TimeSolvZeroBalanceEmailService.EmailOutcome(wi, false, 'fail msg');
        System.assertEquals(false, outcome.success);
        System.assertEquals('fail msg', outcome.errorMessage);
        System.assertEquals(wi, outcome.workItem);
    }

    @IsTest
    static void testRealSendPathHandlesFailure() {
        TimeSolvZeroBalanceEmailService svc = buildService();
        // Don't set testEmailOutcomes so real send() path executes
        TimeSolvZeroBalanceEmailService.NotificationWorkItem wi =
            new TimeSolvZeroBalanceEmailService.NotificationWorkItem(
                UserInfo.getUserId(), UserInfo.getUserId(), UserInfo.getUserId(),
                TimeSolvZeroBalanceEmailService.ReminderType.FIRST);
        Test.startTest();
        List<TimeSolvZeroBalanceEmailService.EmailOutcome> results =
            svc.send(new List<TimeSolvZeroBalanceEmailService.NotificationWorkItem>{ wi });
        Test.stopTest();
        System.assertEquals(1, results.size());
        System.assertEquals(false, results[0].success);
        cleanup();
    }
}