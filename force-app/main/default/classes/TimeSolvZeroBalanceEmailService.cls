/**
 * @description Sends Zero Balance reminder emails using configured email templates
 *              and the configured Org-Wide Email Address.
 *
 * @author Sanders
 */
public without sharing class TimeSolvZeroBalanceEmailService {

    /**
     * @description Explicit reminder type.
     */
    public enum ReminderType {
        FIRST,
        SECOND
    }

    /**
     * @description Work item representing one Account/contact reminder to send.
     */
    public class NotificationWorkItem {
        public Id accountId { get; private set; }
        public Id contactId { get; private set; }
        public Id ownerId { get; private set; }
        public ReminderType reminderType { get; private set; }

        public NotificationWorkItem(
            Id accountId,
            Id contactId,
            Id ownerId,
            ReminderType reminderType
        ) {
            this.accountId = accountId;
            this.contactId = contactId;
            this.ownerId = ownerId;
            this.reminderType = reminderType;
        }
    }

    /**
     * @description Result for one attempted email send.
     */
    public class EmailOutcome {
        public NotificationWorkItem workItem { get; private set; }
        public Boolean success { get; private set; }
        public String errorMessage { get; private set; }

        public EmailOutcome(
            NotificationWorkItem workItem,
            Boolean success,
            String errorMessage
        ) {
            this.workItem = workItem;
            this.success = success;
            this.errorMessage = errorMessage;
        }
    }

    /**
     * @description Maximum number of email messages sent per Messaging.sendEmail call.
     */
    private static final Integer MAX_EMAILS_PER_SEND_CALL = 10;

    /**
     * @description Active runtime configuration.
     */
    private final TimeSolvZeroBalanceConfig config;

    /**
     * @description Resolved Org-Wide Email Address Id.
     */
    private final Id orgWideEmailAddressId;

    /**
     * @description Template Ids keyed by reminder type.
     */
    private final Map<ReminderType, Id> templateIdByReminderType;

    /**
     * @description Configuration problems found during initialization.
     */
    private final List<String> configurationErrors = new List<String>();

    /**
     * @description Test-only flag to bypass setup lookups.
     */
    @TestVisible
    private static Boolean bypassSetupLookups = false;

    /**
     * @description Test-only configured flag override.
     */
    @TestVisible
    private static Boolean testConfigured;

    /**
     * @description Test-only configuration error override.
     */
    @TestVisible
    private static List<String> testConfigurationErrors;

    /**
     * @description Test-only send outcome override.
     */
    @TestVisible
    private static List<EmailOutcome> testEmailOutcomes;

    /**
     * @description Builds the email service with resolved runtime dependencies.
     * @param config Active configuration.
     * @param repository Repository for supporting lookups.
     */
    public TimeSolvZeroBalanceEmailService(
        TimeSolvZeroBalanceConfig config,
        TimeSolvZeroBalanceRepository repository
    ) {
        this.config = config;

        if (Test.isRunningTest() && bypassSetupLookups) {
            this.orgWideEmailAddressId = null;
            this.templateIdByReminderType = new Map<ReminderType, Id>();
            return;
        }

        this.orgWideEmailAddressId = repository.getOrgWideEmailAddressId(config.orgWideEmailAddress);

        Map<String, Id> templateIds = repository.getEmailTemplateIds(new Set<String>{
            config.firstTemplateDeveloperName,
            config.secondTemplateDeveloperName
        });

        this.templateIdByReminderType = new Map<ReminderType, Id>{
            ReminderType.FIRST => templateIds.get(config.firstTemplateDeveloperName),
            ReminderType.SECOND => templateIds.get(config.secondTemplateDeveloperName)
        };

        if (this.orgWideEmailAddressId == null) {
            configurationErrors.add(
                'Org-Wide Email Address not found for Address = ' + config.orgWideEmailAddress
            );
        }

        if (templateIdByReminderType.get(ReminderType.FIRST) == null) {
            configurationErrors.add(
                'First reminder email template not found for DeveloperName = ' +
                config.firstTemplateDeveloperName
            );
        }

        if (templateIdByReminderType.get(ReminderType.SECOND) == null) {
            configurationErrors.add(
                'Second reminder email template not found for DeveloperName = ' +
                config.secondTemplateDeveloperName
            );
        }
    }

    /**
     * @description Test helper to override configuration status and errors.
     * @param configured Whether the service should behave as configured.
     * @param errors Configuration error list to return in tests.
     */
    @TestVisible
    static void setTestConfiguration(Boolean configured, List<String> errors) {
        bypassSetupLookups = true;
        testConfigured = configured;
        testConfigurationErrors = (errors == null)
            ? new List<String>()
            : new List<String>(errors);
    }

    /**
     * @description Test helper to override send outcomes.
     * @param outcomes Outcomes to return from send().
     */
    @TestVisible
    static void setTestEmailOutcomes(List<EmailOutcome> outcomes) {
        testEmailOutcomes = (outcomes == null)
            ? null
            : new List<EmailOutcome>(outcomes);
    }

    /**
     * @description Clears all test-only overrides.
     */
    @TestVisible
    static void clearTestOverrides() {
        bypassSetupLookups = false;
        testConfigured = null;
        testConfigurationErrors = null;
        testEmailOutcomes = null;
    }

    /**
     * @description True when Org-Wide Email Address and templates were resolved successfully.
     * @return Boolean.
     */
    public Boolean isConfigured() {
        if (Test.isRunningTest() && bypassSetupLookups && testConfigured != null) {
            return testConfigured;
        }
        return configurationErrors.isEmpty();
    }

    /**
     * @description Returns configuration problems found during construction.
     * @return List of config error messages.
     */
    public List<String> getConfigurationErrors() {
        if (Test.isRunningTest() && bypassSetupLookups && testConfigurationErrors != null) {
            return new List<String>(testConfigurationErrors);
        }
        return new List<String>(configurationErrors);
    }

    /**
     * @description Sends emails in chunks and returns one outcome per work item.
     * @param workItems Pending notification work items.
     * @return Outcomes for each attempted email.
     */
    public List<EmailOutcome> send(List<NotificationWorkItem> workItems) {
        if (Test.isRunningTest() && testEmailOutcomes != null) {
            return new List<EmailOutcome>(testEmailOutcomes);
        }

        List<EmailOutcome> outcomes = new List<EmailOutcome>();

        if (workItems == null || workItems.isEmpty()) {
            return outcomes;
        }

        Integer startIndex = 0;

        while (startIndex < workItems.size()) {
            Integer endIndex = Math.min(startIndex + MAX_EMAILS_PER_SEND_CALL, workItems.size());

            List<NotificationWorkItem> emailWindow = new List<NotificationWorkItem>();
            for (Integer i = startIndex; i < endIndex; i++) {
                emailWindow.add(workItems[i]);
            }

            List<Messaging.Email> emailMessages = new List<Messaging.Email>();
            for (NotificationWorkItem workItem : emailWindow) {
                emailMessages.add(buildEmailMessage(workItem));
            }

            try {
                List<Messaging.SendEmailResult> results = Messaging.sendEmail(emailMessages, false);

                for (Integer i = 0; i < results.size(); i++) {
                    Messaging.SendEmailResult result = results[i];
                    NotificationWorkItem workItem = emailWindow[i];

                    if (result != null && result.isSuccess()) {
                        outcomes.add(new EmailOutcome(workItem, true, null));
                    } else {
                        outcomes.add(
                            new EmailOutcome(workItem, false, buildSendErrorMessage(result))
                        );
                    }
                }
            } catch (Exception ex) {
                for (NotificationWorkItem workItem : emailWindow) {
                    outcomes.add(
                        new EmailOutcome(workItem, false, 'Email send exception: ' + ex.getMessage())
                    );
                }
            }

            startIndex = endIndex;
        }

        return outcomes;
    }

    /**
     * @description Builds one templated email message.
     * @param workItem Pending work item.
     * @return SingleEmailMessage.
     */
    private Messaging.SingleEmailMessage buildEmailMessage(NotificationWorkItem workItem) {
        Messaging.SingleEmailMessage email = new Messaging.SingleEmailMessage();
        email.setTemplateId(templateIdByReminderType.get(workItem.reminderType));
        email.setTargetObjectId(workItem.contactId);
        email.setTreatTargetObjectAsRecipient(true);
        email.setWhatId(workItem.accountId);
        email.setOrgWideEmailAddressId(orgWideEmailAddressId);
        email.setSaveAsActivity(true);
        return email;
    }

    /**
     * @description Creates a readable error message from a SendEmailResult.
     * @param result SendEmailResult row.
     * @return Error message.
     */
    private String buildSendErrorMessage(Messaging.SendEmailResult result) {
        if (result == null || result.getErrors() == null || result.getErrors().isEmpty()) {
            return 'Unknown email send failure.';
        }

        List<String> messages = new List<String>();
        for (Messaging.SendEmailError err : result.getErrors()) {
            messages.add(err.getMessage());
        }

        return String.join(messages, ' | ');
    }
}