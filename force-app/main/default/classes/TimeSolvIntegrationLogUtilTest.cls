@isTest(SeeAllData=false)
private class TimeSolvIntegrationLogUtilTest {
    @testSetup
    static void setup() {
        // Create a single Account for all tests
        Account acct = new Account(Name = 'Test Account');
        insert acct;
    }

    @isTest
    static void testEmptyBufferAndClear() {
        // When no logs are buffered, savePendingLogs() returns an empty list
        Database.SaveResult[] emptyStart = TimeSolvIntegrationLogUtil.savePendingLogs();
        System.assertEquals(0, emptyStart.size(), 'No logs should be pending initially');

        // Buffer a warning then clear; savePendingLogs() must still be empty
        Account acct = [SELECT Id FROM Account LIMIT 1];
        TimeSolvIntegrationLogUtil.logWarning(
            acct.Id,
            TimeSolvIntegrationLogUtil.INTEGRATION_TYPE_ZERO_TRUST_BALANCE,
            'This will be cleared'
        );
        TimeSolvIntegrationLogUtil.clearPendingLogs();
        Database.SaveResult[] afterClear = TimeSolvIntegrationLogUtil.savePendingLogs();
        System.assertEquals(0, afterClear.size(), 'Buffer was cleared, so no logs to save');
    }

    @isTest
    static void testLogErrorWarningAndSave() {
        Account acct = [SELECT Id FROM Account LIMIT 1];

        // Buffer an Error (use DmlException to simulate)
        DmlException simulatedEx = new DmlException('Simulated failure');
        TimeSolv_Integration_Log__c errLog = TimeSolvIntegrationLogUtil.logError(
            acct.Id,
            TimeSolvIntegrationLogUtil.INTEGRATION_TYPE_CLIENT,
            'Error occurred',
            simulatedEx
        );
        System.assertEquals(acct.Id,         errLog.Account__c);
        System.assertEquals('Error',         errLog.Type__c);
        System.assertEquals('Client Creation', errLog.Integration_Type__c);
        System.assertEquals('Error occurred', errLog.Message__c);
        System.assertNotEquals(null,         errLog.Stack_Trace__c,
                             'Stack trace should be populated for errors');

        // Buffer a Warning
        TimeSolv_Integration_Log__c warnLog = TimeSolvIntegrationLogUtil.logWarning(
            acct.Id,
            TimeSolvIntegrationLogUtil.INTEGRATION_TYPE_TRUST,
            'Just a warning'
        );
        System.assertEquals('Warning',      warnLog.Type__c);
        System.assertEquals(null,           warnLog.Stack_Trace__c,
                             'Warnings should have no stack trace');

        // Persist both
        Test.startTest();
            Database.SaveResult[] results = TimeSolvIntegrationLogUtil.savePendingLogs();
        Test.stopTest();
        System.assertEquals(2, results.size(), 'Both logs should be inserted');
        for (Database.SaveResult r : results) {
            System.assert(r.isSuccess(), 'Each pending log must save successfully');
        }

        // Buffer should now be empty
        Database.SaveResult[] noneLeft = TimeSolvIntegrationLogUtil.savePendingLogs();
        System.assertEquals(0, noneLeft.size(), 'Buffer is cleared after save');
    }

    @isTest
    static void testGetErrorMessages() {
        // Cause a DML error to test getErrorMessages()
        Account bad = new Account(); // missing required Name
        Database.SaveResult[] sr = Database.insert(
            new List<Account>{ bad },
            false
        );
        List<String> msgs = TimeSolvIntegrationLogUtil.getErrorMessages(
            sr[0].getErrors()
        );
        System.assertEquals(1, msgs.size(), 'One error message expected');
        System.assert(
            msgs[0].contains('REQUIRED_FIELD_MISSING'),
            'Error status code and message should be included'
        );
    }

    @isTest
    static void testCreateTask_BusinessAccount() {
        Account acct = [SELECT Id FROM Account LIMIT 1];

        // Build an in-memory log record (no need to insert)
        TimeSolv_Integration_Log__c logRec = new TimeSolv_Integration_Log__c(
            Account__c          = acct.Id,
            Type__c             = TimeSolvIntegrationLogUtil.LOG_TYPE_WARNING,
            Integration_Type__c = TimeSolvIntegrationLogUtil.INTEGRATION_TYPE_TOKEN,
            Message__c          = 'Token will expire',
            Stack_Trace__c      = null,
            Timestamp__c        = System.now()
        );

        Task t = TimeSolvIntegrationLogUtil.createTaskFromLog(logRec);

        // Verify Task fields
        System.assertEquals(acct.Id, t.WhatId,     'Task should link to the Account');
        System.assertEquals(null,    t.WhoId,      'No WhoId for business accounts');
        System.assert(t.Subject.contains('TimeSolv Warning: Token Retrieval'),
                      'Subject should include type and integration');
        System.assertEquals('Normal',    t.Priority, 'Warnings get Normal priority');
        System.assertEquals('Completed', t.Status,   'Warnings get Completed status');
        System.assert(
            t.Description.contains('Integration Type: Token Retrieval') &&
            t.Description.contains('Message: Token will expire'),
            'Description must include integration type and message'
        );
    }

    @isTest
    static void testCreateTask_ErrorDescription() {
        Account acct = [SELECT Id FROM Account LIMIT 1];

        TimeSolv_Integration_Log__c logRec = new TimeSolv_Integration_Log__c(
            Account__c          = acct.Id,
            Type__c             = TimeSolvIntegrationLogUtil.LOG_TYPE_ERROR,
            Integration_Type__c = TimeSolvIntegrationLogUtil.INTEGRATION_TYPE_RETAINER,
            Message__c          = 'Retainer failed',
            Stack_Trace__c      = 'StackLine1\nStackLine2',
            Timestamp__c        = System.now()
        );

        Task t = TimeSolvIntegrationLogUtil.createTaskFromLog(logRec);

        System.assertEquals(acct.Id,   t.WhatId,  'Error tasks link to Account');
        System.assertEquals('High',    t.Priority,'Errors get High priority');
        System.assertEquals('Not Started', t.Status, 'Errors get Not Started status');
        System.assert(
            t.Description.contains('Stack Trace:') &&
            t.Description.contains('StackLine1'),
            'Error tasks should include the stack trace'
        );
    }
}