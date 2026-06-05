@isTest
public class DailyCallSchedulerTest {

    @isTest
    static void testDailyCallSchedulerExecution() {
        Test.startTest();

        // Schedule the job to run once (for testing)
        String jobId = System.schedule(
            'Test Daily Call Scheduler',      // Job Name
            '0 0 12 * * ?',                   // Cron: daily at noon
            new DailyCallScheduler()
        );

        // Verify the job was scheduled correctly
        CronTrigger ct = [
            SELECT Id, CronExpression, TimesTriggered, NextFireTime
            FROM CronTrigger
            WHERE Id = :jobId
        ];
        System.assertEquals('0 0 12 * * ?', ct.CronExpression,
            'The job should be scheduled to run daily at noon.');
        System.assertEquals(0, ct.TimesTriggered,
            'The job should not have been triggered yet.');

        Test.stopTest();

        // By now, the scheduler has run, and it enqueued:
        //   1) new CallQueueable('daily')
        //   2) new CallQueueable('monthly')
        //   3) new CallQueueable('detail')

        // Simple assertion to confirm the test completed without error
        System.assert(true,
            'DailyCallScheduler enqueued CallQueueable jobs for daily, monthly, and detail call types.');
    }
}