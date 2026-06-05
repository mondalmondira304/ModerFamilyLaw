public class TimeSolvNotifyClientZeroBalanceScheduler implements Schedulable {

    @TestVisible
    private static Boolean TEST_THROW_SCHEDULER_EXCEPTION = false;

    public class ForcedTestException extends Exception {}

    public void execute(SchedulableContext context) {
        try {
            if (Test.isRunningTest() && TEST_THROW_SCHEDULER_EXCEPTION) {
                throw new ForcedTestException('Forced scheduler exception for test');
            }

            Id jobId = timeSolvNotifyClientZeroBalanceBatch.runBatch(null);

            System.debug(
                LoggingLevel.INFO,
                '[Scheduler] Launched timeSolvNotifyClientZeroBalanceBatch' +
                ' | jobId=' + jobId
            );
        } catch (Exception ex) {
            System.debug(
                LoggingLevel.ERROR,
                '[Scheduler] Failed to launch zero-balance batch: ' + ex.getMessage()
            );
            throw ex;
        }
    }
}