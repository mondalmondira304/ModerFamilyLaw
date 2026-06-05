global without sharing class timeSolvNotifyClientZeroBalanceBatch
    implements Database.Batchable<SObject> {

    private static final Boolean DEBUG = false;

    private static final String INTEGRATION_TYPE =
        TimeSolvIntegrationLogUtil.INTEGRATION_TYPE_ZERO_TRUST_BALANCE;

    @TestVisible
    private static Boolean TEST_THROW_EXECUTE_EXCEPTION = false;
    @TestVisible
    private static Boolean TEST_THROW_RUN_BATCH_EXCEPTION = false;
    @TestVisible
    private static Boolean TEST_THROW_START_EXCEPTION = false;

    public class ForcedTestException extends Exception {}

    public static Id runBatch(Integer batchSize) {
        try {
            if (Test.isRunningTest() && TEST_THROW_RUN_BATCH_EXCEPTION) {
                throw new ForcedTestException('Forced batch runBatch exception for test');
            }
            TimeSolvZeroBalanceConfig config = TimeSolvZeroBalanceConfig.getActive();

            Integer resolvedBatchSize = (batchSize == null || batchSize <= 0)
                ? config.defaultBatchSize
                : batchSize;

            return Database.executeBatch(
                new timeSolvNotifyClientZeroBalanceBatch(),
                resolvedBatchSize
            );
        } catch (Exception ex) {
            TimeSolvIntegrationLogUtil.clearPendingLogs();
            TimeSolvIntegrationLogUtil.logError(
                null,
                INTEGRATION_TYPE,
                'Zero balance batch failed to start: ' + ex.getMessage(),
                ex
            );
            TimeSolvIntegrationLogUtil.savePendingLogs();
            throw ex;
        }
    }

    global Database.QueryLocator start(Database.BatchableContext bc) {
        try {
            if (Test.isRunningTest() && TEST_THROW_START_EXCEPTION) {
                throw new ForcedTestException('Forced batch start exception for test');
            }
            TimeSolvZeroBalanceConfig config = TimeSolvZeroBalanceConfig.getActive();
            TimeSolvZeroBalanceRepository repository = new TimeSolvZeroBalanceRepository();

            Datetime recentThreshold = System.now().addDays(-config.reminderIntervalDays);
            Set<Id> recentlyNotifiedAccountIds =
                repository.getRecentlyNotifiedAccountIds(config.taskSubject, recentThreshold);

            debug(
                'START recentThreshold=' + recentThreshold +
                ', recentAccounts=' + recentlyNotifiedAccountIds.size()
            );

            return repository.getCandidateAccounts(config, recentlyNotifiedAccountIds);
        } catch (Exception ex) {
            TimeSolvIntegrationLogUtil.clearPendingLogs();
            TimeSolvIntegrationLogUtil.logError(
                null,
                INTEGRATION_TYPE,
                'Zero balance batch start failed: ' + ex.getMessage(),
                ex
            );
            TimeSolvIntegrationLogUtil.savePendingLogs();
            throw ex;
        }
    }

    global void execute(Database.BatchableContext bc, List<SObject> scope) {
        if (scope == null || scope.isEmpty()) {
            return;
        }

        List<Account> accountScope = (List<Account>) scope;

        TimeSolvIntegrationLogUtil.clearPendingLogs();

        try {
            if (Test.isRunningTest() && TEST_THROW_EXECUTE_EXCEPTION) {
                throw new ForcedTestException('Forced batch execute exception for test');
            }

            TimeSolvZeroBalanceConfig config = TimeSolvZeroBalanceConfig.getActive();
            TimeSolvZeroBalanceRepository repository = new TimeSolvZeroBalanceRepository();
            TimeSolvZeroBalanceEmailService emailService =
                new TimeSolvZeroBalanceEmailService(config, repository);
            TimeSolvZeroBalanceNotificationService notificationService =
                new TimeSolvZeroBalanceNotificationService(config, repository, emailService);

            notificationService.process(accountScope);

            TimeSolvIntegrationLogUtil.savePendingLogs();

            debug('EXECUTE completed. Scope size=' + accountScope.size());
        } catch (Exception ex) {
            TimeSolvIntegrationLogUtil.logError(
                null,
                INTEGRATION_TYPE,
                'Zero balance batch execute failed: ' + ex.getMessage(),
                ex
            );
            TimeSolvIntegrationLogUtil.savePendingLogs();
            throw ex;
        }
    }

    global void finish(Database.BatchableContext bc) {
        try {
            TimeSolvIntegrationLogUtil.clearPendingLogs();
        } catch (Exception ex) {
            TimeSolvIntegrationLogUtil.clearPendingLogs();
            TimeSolvIntegrationLogUtil.logError(
                null,
                INTEGRATION_TYPE,
                'Zero balance batch finish failed: ' + ex.getMessage(),
                ex
            );
            TimeSolvIntegrationLogUtil.savePendingLogs();
            throw ex;
        }
    }

    private void debug(String message) {
        if (DEBUG) {
            System.debug('timeSolvNotifyClientZeroBalanceBatch | ' + message);
        }
    }
}