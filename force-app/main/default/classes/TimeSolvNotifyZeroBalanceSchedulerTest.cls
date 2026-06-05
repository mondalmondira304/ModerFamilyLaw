@IsTest
private class TimeSolvNotifyZeroBalanceSchedulerTest {

    @IsTest
    static void testSchedulerExecutesBatch() {
        TimeSolvZeroBalanceConfig.setTestConfig(50, 7, 'Zero Trust Balance Client Notification',
            'reception@modernfamilylaw.com', 'First_Template', 'Second_Template',
            'Modern Family Law CC Authorization');
        TimeSolvZeroBalanceEmailService.setTestConfiguration(true, new List<String>());

        Test.startTest();
        String jobId = System.schedule('ZB Test ' + System.now().getTime(),
            '0 0 0 1 1 ? 2099', new TimeSolvNotifyClientZeroBalanceScheduler());
        Test.stopTest();

        System.assertNotEquals(null, jobId);
        TimeSolvZeroBalanceConfig.clearTestConfig();
        TimeSolvZeroBalanceEmailService.clearTestOverrides();
    }

    @IsTest
    static void testSchedulerHandlesException() {
        TimeSolvNotifyClientZeroBalanceScheduler.TEST_THROW_SCHEDULER_EXCEPTION = true;

        Test.startTest();
        try {
            new TimeSolvNotifyClientZeroBalanceScheduler().execute(null);
            System.assert(false, 'Should have thrown');
        } catch (TimeSolvNotifyClientZeroBalanceScheduler.ForcedTestException e) {
            System.assert(e.getMessage().contains('Forced scheduler exception'));
        }
        Test.stopTest();

        TimeSolvNotifyClientZeroBalanceScheduler.TEST_THROW_SCHEDULER_EXCEPTION = false;
    }
}