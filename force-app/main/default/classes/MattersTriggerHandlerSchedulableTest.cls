@isTest
public class MattersTriggerHandlerSchedulableTest {
    @isTest
    static void testSchedulable() {
        Test.startTest();
            String jobId = System.schedule(
                'Test Daily Call Scheduler',      // Job Name
                '0 0 12 * * ?',                   // Cron: daily at noon
                new MattersTriggerHandlerSchedulable()
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
    }
}