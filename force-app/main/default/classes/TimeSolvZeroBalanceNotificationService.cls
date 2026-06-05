/**
 * @description Business logic service for TimeSolv zero-balance client reminders.
 *              Logging ownership in this class:
 *              - account-level data issues
 *              - email send failures
 *              - suppression task insert failures
 *
 *              Intentionally does NOT log normal business outcomes like:
 *              - waiting for 7-day interval
 *              - already sent twice
 *
 * @author Sanders
 */
public without sharing class TimeSolvZeroBalanceNotificationService {

    /**
     * @description Exception type for service-level processing failures.
     */
    public class NotificationServiceException extends Exception {}

    /**
     * @description Internal eligibility state for a given Account.
     */
    private enum ReminderEligibility {
        FIRST_DUE,
        SECOND_DUE,
        WAITING_INTERVAL,
        COMPLETE
    }

    private static final String INTEGRATION_TYPE =
        TimeSolvIntegrationLogUtil.INTEGRATION_TYPE_ZERO_TRUST_BALANCE;

    private final TimeSolvZeroBalanceConfig config;
    private final TimeSolvZeroBalanceRepository repository;
    private final TimeSolvZeroBalanceEmailService emailService;

    /**
     * @description Constructor with dependency injection.
     * @param config Active configuration.
     * @param repository Repository dependency.
     * @param emailService Email sending dependency.
     */
    public TimeSolvZeroBalanceNotificationService(
        TimeSolvZeroBalanceConfig config,
        TimeSolvZeroBalanceRepository repository,
        TimeSolvZeroBalanceEmailService emailService
    ) {
        this.config = config;
        this.repository = repository;
        this.emailService = emailService;
    }

    /**
     * @description Processes one batch execute scope in bulk.
     * @param scope Accounts in the current batch execute.
     */
    public void process(List<Account> scope) {
        if (scope == null || scope.isEmpty()) {
            return;
        }

        Set<Id> accountIds = new Set<Id>();
        Set<Id> responsibleAttorneyIds = new Set<Id>();

        for (Account acc : scope) {
            accountIds.add(acc.Id);
            if (acc.Responsible_Attorney__c != null) {
                responsibleAttorneyIds.add(acc.Responsible_Attorney__c);
            }
        }

        Map<Id, User> activeUsersById = repository.getActiveUsersById(responsibleAttorneyIds);
        Map<Id, List<Task>> suppressionTasksByAccountId =
            repository.getSuppressionTasksByAccountId(accountIds, config.taskSubject);

        List<TimeSolvZeroBalanceEmailService.NotificationWorkItem> workItems =
            new List<TimeSolvZeroBalanceEmailService.NotificationWorkItem>();

        for (Account acc : scope) {
            if (!qualifiesForReminder(acc)) {
                continue;
            }

            if (acc.PersonContactId == null || String.isBlank(acc.PersonEmail)) {
                TimeSolvIntegrationLogUtil.logWarning(
                    acc.Id,
                    INTEGRATION_TYPE,
                    'Skipped zero-balance reminder: missing PersonContactId or PersonEmail.'
                );
                continue;
            }

            if (acc.Responsible_Attorney__c == null || !activeUsersById.containsKey(acc.Responsible_Attorney__c)) {
                TimeSolvIntegrationLogUtil.logWarning(
                    acc.Id,
                    INTEGRATION_TYPE,
                    'Skipped zero-balance reminder: missing or inactive Responsible Attorney.'
                );
                continue;
            }

            ReminderEligibility eligibility = determineEligibility(
                suppressionTasksByAccountId.get(acc.Id),
                System.now()
            );

            if (eligibility == ReminderEligibility.WAITING_INTERVAL
                || eligibility == ReminderEligibility.COMPLETE) {
                continue;
            }

            workItems.add(
                new TimeSolvZeroBalanceEmailService.NotificationWorkItem(
                    acc.Id,
                    acc.PersonContactId,
                    acc.Responsible_Attorney__c,
                    eligibility == ReminderEligibility.FIRST_DUE
                        ? TimeSolvZeroBalanceEmailService.ReminderType.FIRST
                        : TimeSolvZeroBalanceEmailService.ReminderType.SECOND
                )
            );
        }

        if (workItems.isEmpty()) {
            return;
        }

        if (!emailService.isConfigured()) {
            String configError = String.join(emailService.getConfigurationErrors(), ' | ');
            for (TimeSolvZeroBalanceEmailService.NotificationWorkItem workItem : workItems) {
                TimeSolvIntegrationLogUtil.logError(
                    workItem.accountId,
                    INTEGRATION_TYPE,
                    configError,
                    new NotificationServiceException(configError)
                );
            }
            return;
        }

        List<TimeSolvZeroBalanceEmailService.EmailOutcome> outcomes = emailService.send(workItems);
        List<Task> tasksToInsert = new List<Task>();
        List<Id> taskAccountIdsInOrder = new List<Id>();

        for (TimeSolvZeroBalanceEmailService.EmailOutcome outcome : outcomes) {
            if (outcome.success) {
                tasksToInsert.add(buildSuppressionTask(outcome.workItem));
                taskAccountIdsInOrder.add(outcome.workItem.accountId);
            } else {
                TimeSolvIntegrationLogUtil.logError(
                    outcome.workItem.accountId,
                    INTEGRATION_TYPE,
                    outcome.errorMessage,
                    new NotificationServiceException(outcome.errorMessage)
                );
            }
        }

        if (!tasksToInsert.isEmpty()) {
            Database.SaveResult[] taskResults = repository.insertSuppressionTasks(tasksToInsert);

            for (Integer i = 0; i < taskResults.size(); i++) {
                if (!taskResults[i].isSuccess()) {
                    String errorMessage = buildDmlErrorMessage(taskResults[i]);
                    TimeSolvIntegrationLogUtil.logError(
                        taskAccountIdsInOrder[i],
                        INTEGRATION_TYPE,
                        'Suppression Task insert failed: ' + errorMessage,
                        new NotificationServiceException(errorMessage)
                    );
                }
            }
        }
    }

    /**
     * @description Mirrors the batch candidate criteria defensively.
     * @param acc Account row.
     * @return True if the Account still qualifies.
     */
    private Boolean qualifiesForReminder(Account acc) {
        Decimal balance = acc.Timesolv_TrustAccount_Balance__c;
        Decimal below = acc.Timesolv_TrustAccount_Replenish_Below__c;
        Decimal toValue = acc.Timesolv_TrustAccount_Replenish_To__c;

        return (balance == null || balance == 0)
            && below != null && below > 0
            && toValue != null && toValue > 0;
    }

    /**
     * @description Determines whether to send first reminder, second reminder, or nothing.
     * @param existingTasks Existing suppression Tasks for the Account, oldest first.
     * @param nowDT Current datetime.
     * @return Reminder eligibility state.
     */
    private ReminderEligibility determineEligibility(List<Task> existingTasks, Datetime nowDT) {
        if (existingTasks == null || existingTasks.isEmpty()) {
            return ReminderEligibility.FIRST_DUE;
        }

        if (existingTasks.size() >= 2) {
            return ReminderEligibility.COMPLETE;
        }

        Datetime secondReminderThreshold = nowDT.addDays(-config.reminderIntervalDays);
        Task firstTask = existingTasks[0];

        if (firstTask.CreatedDate <= secondReminderThreshold) {
            return ReminderEligibility.SECOND_DUE;
        }

        return ReminderEligibility.WAITING_INTERVAL;
    }

    /**
     * @description Builds the suppression Task.
     * @param workItem Successful email work item.
     * @return Task to insert.
     */
    private Task buildSuppressionTask(TimeSolvZeroBalanceEmailService.NotificationWorkItem workItem) {
        Task suppressionTask = new Task();
        suppressionTask.Subject = config.taskSubject;
        suppressionTask.WhatId = workItem.accountId;
        suppressionTask.WhoId = workItem.contactId;
        suppressionTask.OwnerId = workItem.ownerId;
        suppressionTask.Status = 'Completed';
        suppressionTask.Priority = 'Normal';
        suppressionTask.ActivityDate = Date.today();
        suppressionTask.Description = 'Zero balance notice sent';
        return suppressionTask;
    }

    /**
     * @description Builds a readable DML error message.
     * @param saveResult SaveResult row.
     * @return Error message.
     */
    private String buildDmlErrorMessage(Database.SaveResult saveResult) {
        if (saveResult == null || saveResult.getErrors() == null || saveResult.getErrors().isEmpty()) {
            return 'Unknown DML error.';
        }

        return String.join(
            TimeSolvIntegrationLogUtil.getErrorMessages(saveResult.getErrors()),
            ' | '
        );
    }
}