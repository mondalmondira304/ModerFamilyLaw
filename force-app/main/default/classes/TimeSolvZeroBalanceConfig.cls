/**
 * @description Loads and validates the active Zero Balance notification configuration
 *              from Custom Metadata.
 *
 * @author Sanders
 */
public without sharing class TimeSolvZeroBalanceConfig {

    /**
     * @description Configuration exception for missing or invalid metadata.
     */
    public class ConfigException extends Exception {}

    /**
     * @description Cached active config for the current transaction.
     */
    private static TimeSolvZeroBalanceConfig cachedConfig;

    /**
     * @description Test-only override config.
     */
    @TestVisible
    private static TimeSolvZeroBalanceConfig testConfig;

    /**
     * @description Number of days to wait before the 2nd reminder can be sent.
     */
    public Integer reminderIntervalDays { get; private set; }

    /**
     * @description Default batch size for the batch entry point.
     */
    public Integer defaultBatchSize { get; private set; }

    /**
     * @description Suppression Task subject.
     */
    public String taskSubject { get; private set; }

    /**
     * @description Org-Wide Email Address used for sends.
     */
    public String orgWideEmailAddress { get; private set; }

    /**
     * @description First reminder template developer name.
     */
    public String firstTemplateDeveloperName { get; private set; }

    /**
     * @description Second reminder template developer name.
     */
    public String secondTemplateDeveloperName { get; private set; }

    /**
     * @description Agreement name prefix to exclude from the candidate set.
     */
    public String excludedAgreementNamePrefix { get; private set; }

    /**
     * @description Returns the active configuration, loaded once per transaction.
     * @return Active zero balance config.
     */
    public static TimeSolvZeroBalanceConfig getActive() {
        if (Test.isRunningTest() && testConfig != null) {
            return testConfig;
        }

        if (cachedConfig == null) {
            cachedConfig = loadActiveConfig();
        }
        return cachedConfig;
    }

    /**
     * @description Loads exactly one active metadata record and validates required values.
     * @return Validated active config.
     */
    private static TimeSolvZeroBalanceConfig loadActiveConfig() {
        List<TimeSolv_Zero_Balance_Config__mdt> rows = [
            SELECT DeveloperName,
                   Is_Active__c,
                   Default_Batch_Size__c,
                   Reminder_Interval_Days__c,
                   Task_Subject__c,
                   Org_Wide_Email_Address__c,
                   First_Email_Template_Developer_Name__c,
                   Second_Email_Template_Developer_Name__c,
                   Excluded_Agreement_Name_Prefix__c
              FROM TimeSolv_Zero_Balance_Config__mdt
             WHERE Is_Active__c = true
        ];

        if (rows.size() != 1) {
            throw new ConfigException(
                'Expected exactly one active TimeSolv_Zero_Balance_Config__mdt record, found ' + rows.size() + '.'
            );
        }

        TimeSolv_Zero_Balance_Config__mdt row = rows[0];

        TimeSolvZeroBalanceConfig config = new TimeSolvZeroBalanceConfig();
        config.defaultBatchSize = row.Default_Batch_Size__c == null
            ? 50
            : row.Default_Batch_Size__c.intValue();
        config.reminderIntervalDays = row.Reminder_Interval_Days__c == null
            ? 7
            : row.Reminder_Interval_Days__c.intValue();
        config.taskSubject = requireText(row.Task_Subject__c, 'Task_Subject__c');
        config.orgWideEmailAddress = requireText(row.Org_Wide_Email_Address__c, 'Org_Wide_Email_Address__c');
        config.firstTemplateDeveloperName = requireText(
            row.First_Email_Template_Developer_Name__c,
            'First_Email_Template_Developer_Name__c'
        );
        config.secondTemplateDeveloperName = requireText(
            row.Second_Email_Template_Developer_Name__c,
            'Second_Email_Template_Developer_Name__c'
        );
        config.excludedAgreementNamePrefix = requireText(
            row.Excluded_Agreement_Name_Prefix__c,
            'Excluded_Agreement_Name_Prefix__c'
        );

        if (config.defaultBatchSize <= 0) {
            throw new ConfigException('Default_Batch_Size__c must be greater than 0.');
        }

        if (config.reminderIntervalDays < 0) {
            throw new ConfigException('Reminder_Interval_Days__c cannot be negative.');
        }

        return config;
    }

    /**
     * @description Test helper to inject config values without relying on CMDT.
     * @param defaultBatchSize Batch size to use in tests.
     * @param reminderIntervalDays Reminder interval to use in tests.
     * @param taskSubject Suppression Task subject.
     * @param orgWideEmailAddress Org-Wide Email Address.
     * @param firstTemplateDeveloperName First reminder template developer name.
     * @param secondTemplateDeveloperName Second reminder template developer name.
     * @param excludedAgreementNamePrefix Excluded agreement name prefix.
     */
    @TestVisible
    static void setTestConfig(
        Integer defaultBatchSize,
        Integer reminderIntervalDays,
        String taskSubject,
        String orgWideEmailAddress,
        String firstTemplateDeveloperName,
        String secondTemplateDeveloperName,
        String excludedAgreementNamePrefix
    ) {
        TimeSolvZeroBalanceConfig cfg = new TimeSolvZeroBalanceConfig();
        cfg.defaultBatchSize = defaultBatchSize;
        cfg.reminderIntervalDays = reminderIntervalDays;
        cfg.taskSubject = taskSubject;
        cfg.orgWideEmailAddress = orgWideEmailAddress;
        cfg.firstTemplateDeveloperName = firstTemplateDeveloperName;
        cfg.secondTemplateDeveloperName = secondTemplateDeveloperName;
        cfg.excludedAgreementNamePrefix = excludedAgreementNamePrefix;
        testConfig = cfg;
    }

    /**
     * @description Clears the test-only config override.
     */
    @TestVisible
    static void clearTestConfig() {
        testConfig = null;
    }

    /**
     * @description Ensures a text value is populated.
     * @param value Text value.
     * @param fieldName Metadata field name for error clarity.
     * @return Validated non-blank value.
     */
    private static String requireText(String value, String fieldName) {
        if (String.isBlank(value)) {
            throw new ConfigException('Missing required metadata value: ' + fieldName);
        }
        return value.trim();
    }
}