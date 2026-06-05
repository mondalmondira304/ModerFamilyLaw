@IsTest(SeeAllData=false)
private class TimeSolvIntegrationStatusTaskTest {

    @TestSetup
    static void setupData() {
        // 1) Create a single Account to use in all stages
        Account acc = new Account(Name='Test Account');
        insert acc;
    }

    @IsTest
    static void testMultiStageStatusTask() {
        // Pull in the account
        Account acc = [SELECT Id FROM Account WHERE Name='Test Account' LIMIT 1];

        Test.startTest();
            // —— Stage A: initial Success —— 
            TimeSolvIntegrationStatusTask.updateIntegrationStatusTask(
                acc,
                'Stage A',
                'Success',
                'First message',
                null
            );
            // Verify creation + description
            Task t = [
                SELECT Id, Status, Description
                  FROM Task
                 WHERE WhatId = :acc.Id
                   AND Subject = 'TimeSolv Integration Status'
                 LIMIT 1
            ];
            System.assertEquals('In Progress', t.Status,
                'New task should start In Progress');
            System.assert(
                t.Description.contains('Stage A: Success - First message'),
                'Should have initial line'
            );

            // —— Stage B: Error —— 
            TimeSolvIntegrationStatusTask.updateIntegrationStatusTask(
                acc,
                'Stage B',
                'Error',
                null,
                acc.Id  // use acc.Id as dummy logId
            );
            t = [SELECT Status, Description FROM Task WHERE Id = :t.Id];
            System.assertEquals('Blocked', t.Status,
                'Error should mark it Blocked');
            System.assert(
                t.Description.contains('Stage B: Error'),
                'Should append the error line'
            );
            System.assert(
                t.Description.contains('(Log: ' + acc.Id + ')'),
                'Should include the logId'
            );
            System.assert(
                t.Description.contains('Stage A: Success'),
                'Original line must still be there'
            );

            // —— Invoice Retainer: Success —— 
            TimeSolvIntegrationStatusTask.updateIntegrationStatusTask(
                acc,
                'Invoice Retainer',
                'Success',
                'Done invoice',
                null
            );
        Test.stopTest();

        // Final verification: Completed + invoice line
        t = [SELECT Status, Description FROM Task WHERE Id = :t.Id];
        System.assertEquals('Completed', t.Status,
            'Invoice Retainer + Success should mark Completed');
        System.assert(
            t.Description.contains('Invoice Retainer: Success - Done invoice'),
            'Should include the invoice‐success line'
        );
    }
}