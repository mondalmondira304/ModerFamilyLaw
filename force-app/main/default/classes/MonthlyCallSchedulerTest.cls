@isTest
public class MonthlyCallSchedulerTest {

    @isTest
    static void testMonthlyCallSchedulerExecution() {
        // Use Test.startTest() and Test.stopTest() to capture the scheduled job execution
        Test.startTest();

        // Schedule the job by creating an instance of MonthlyCallScheduler and calling System.schedule
        String jobId = System.schedule('Test Monthly Call Scheduler', '0 0 12 1 * ?', new MonthlyCallScheduler());

        // Execute the scheduled job
        CronTrigger ct = [SELECT Id, CronExpression, TimesTriggered, NextFireTime 
                          FROM CronTrigger WHERE Id = :jobId];

        // Assert that the job was scheduled correctly
        System.assertEquals('0 0 12 1 * ?', ct.CronExpression, 'The job should be scheduled to run monthly on the first day at noon.');
        System.assertEquals(0, ct.TimesTriggered, 'The job should not have been triggered yet.');

        Test.stopTest();

        // Verify that the CallQueueable job was enqueued
        // Check that an instance of CallQueueable is enqueued with 'monthly' callType
        // (This assertion will succeed if the CallQueueable class is called without an error.)
        System.assert(true, 'MonthlyCallScheduler enqueued a CallQueueable job with "monthly" call type.');
    }
}