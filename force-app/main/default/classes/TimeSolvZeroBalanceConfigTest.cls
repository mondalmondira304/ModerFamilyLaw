@IsTest
private class TimeSolvZeroBalanceConfigTest {

    /**
     * @description Verifies that test configuration values are returned by getActive()
     *              when a test override is provided.
     */
    @IsTest
    static void testGetActiveReturnsInjectedTestConfig() {
        TimeSolvZeroBalanceConfig.clearTestConfig();

        TimeSolvZeroBalanceConfig.setTestConfig(
            25,
            7,
            'Zero Trust Balance Client Notification',
            'reception@modernfamilylaw.com',
            'First_Template',
            'Second_Template',
            'Modern Family Law CC Authorization'
        );

        Test.startTest();
        TimeSolvZeroBalanceConfig config = TimeSolvZeroBalanceConfig.getActive();
        Test.stopTest();

        System.assertNotEquals(null, config, 'Config should be returned.');
        System.assertEquals(25, config.defaultBatchSize, 'Batch size should match injected value.');
        System.assertEquals(7, config.reminderIntervalDays, 'Reminder interval should match injected value.');
        System.assertEquals(
            'Zero Trust Balance Client Notification',
            config.taskSubject,
            'Task subject should match injected value.'
        );
        System.assertEquals(
            'reception@modernfamilylaw.com',
            config.orgWideEmailAddress,
            'Org-Wide Email Address should match injected value.'
        );
        System.assertEquals(
            'First_Template',
            config.firstTemplateDeveloperName,
            'First template developer name should match injected value.'
        );
        System.assertEquals(
            'Second_Template',
            config.secondTemplateDeveloperName,
            'Second template developer name should match injected value.'
        );
        System.assertEquals(
            'Modern Family Law CC Authorization',
            config.excludedAgreementNamePrefix,
            'Excluded agreement prefix should match injected value.'
        );

        TimeSolvZeroBalanceConfig.clearTestConfig();
    }

    /**
     * @description Verifies that the test override can be replaced with a new set of values.
     */
    @IsTest
    static void testSetTestConfigCanBeReplaced() {
        TimeSolvZeroBalanceConfig.clearTestConfig();

        TimeSolvZeroBalanceConfig.setTestConfig(
            10,
            3,
            'First Subject',
            'first@example.com',
            'Template_One',
            'Template_Two',
            'Prefix One'
        );

        TimeSolvZeroBalanceConfig firstConfig = TimeSolvZeroBalanceConfig.getActive();

        System.assertEquals(10, firstConfig.defaultBatchSize);
        System.assertEquals(3, firstConfig.reminderIntervalDays);
        System.assertEquals('First Subject', firstConfig.taskSubject);
        System.assertEquals('first@example.com', firstConfig.orgWideEmailAddress);
        System.assertEquals('Template_One', firstConfig.firstTemplateDeveloperName);
        System.assertEquals('Template_Two', firstConfig.secondTemplateDeveloperName);
        System.assertEquals('Prefix One', firstConfig.excludedAgreementNamePrefix);

        TimeSolvZeroBalanceConfig.setTestConfig(
            50,
            14,
            'Second Subject',
            'second@example.com',
            'Template_A',
            'Template_B',
            'Prefix Two'
        );

        TimeSolvZeroBalanceConfig secondConfig = TimeSolvZeroBalanceConfig.getActive();

        System.assertEquals(50, secondConfig.defaultBatchSize);
        System.assertEquals(14, secondConfig.reminderIntervalDays);
        System.assertEquals('Second Subject', secondConfig.taskSubject);
        System.assertEquals('second@example.com', secondConfig.orgWideEmailAddress);
        System.assertEquals('Template_A', secondConfig.firstTemplateDeveloperName);
        System.assertEquals('Template_B', secondConfig.secondTemplateDeveloperName);
        System.assertEquals('Prefix Two', secondConfig.excludedAgreementNamePrefix);

        TimeSolvZeroBalanceConfig.clearTestConfig();
    }

    /**
     * @description Verifies getActive() loads config from Custom Metadata
     *              when no test override is set.
     */
    @IsTest
    static void testGetActiveLoadsFromMetadata() {
        TimeSolvZeroBalanceConfig.clearTestConfig();

        Test.startTest();
        TimeSolvZeroBalanceConfig config = TimeSolvZeroBalanceConfig.getActive();
        Test.stopTest();

        System.assertNotEquals(null, config, 'Config should be loaded from metadata.');
        System.assert(config.defaultBatchSize > 0, 'Batch size should be positive.');
        System.assert(config.reminderIntervalDays >= 0, 'Reminder interval should be non-negative.');
        System.assert(String.isNotBlank(config.taskSubject), 'Task subject should be populated.');
        System.assert(String.isNotBlank(config.orgWideEmailAddress), 'Org-wide email should be populated.');
        System.assert(String.isNotBlank(config.firstTemplateDeveloperName), 'First template should be populated.');
        System.assert(String.isNotBlank(config.secondTemplateDeveloperName), 'Second template should be populated.');
        System.assert(String.isNotBlank(config.excludedAgreementNamePrefix), 'Excluded prefix should be populated.');
    }

    /**
     * @description Verifies that getActive() caches the config and returns the
     *              same instance on subsequent calls.
     */
    @IsTest
    static void testGetActiveCachesConfig() {
        TimeSolvZeroBalanceConfig.clearTestConfig();

        Test.startTest();
        TimeSolvZeroBalanceConfig first = TimeSolvZeroBalanceConfig.getActive();
        TimeSolvZeroBalanceConfig second = TimeSolvZeroBalanceConfig.getActive();
        Test.stopTest();

        System.assert(first === second, 'Cached config should return the same instance.');
    }

    /**
     * @description Verifies that ConfigException can be instantiated and thrown.
     */
    @IsTest
    static void testConfigExceptionCanBeThrown() {
        Test.startTest();
        try {
            throw new TimeSolvZeroBalanceConfig.ConfigException('Test error');
        } catch (TimeSolvZeroBalanceConfig.ConfigException e) {
            System.assertEquals('Test error', e.getMessage());
        }
        Test.stopTest();
    }

    /**
     * @description Verifies that clearTestConfig removes the injected test config.
     */
    @IsTest
    static void testClearTestConfigRemovesOverride() {
        TimeSolvZeroBalanceConfig.setTestConfig(
            15,
            5,
            'Test Subject',
            'test@example.com',
            'Template_First',
            'Template_Second',
            'Test Prefix'
        );

        System.assertNotEquals(
            null,
            TimeSolvZeroBalanceConfig.testConfig,
            'Test config should be populated before clearing.'
        );

        TimeSolvZeroBalanceConfig.clearTestConfig();

        System.assertEquals(
            null,
            TimeSolvZeroBalanceConfig.testConfig,
            'Test config should be null after clearing.'
        );
    }
}