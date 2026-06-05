@isTest 

public class HubSpotSchedulerTest { 

    @isTest 

    static void testScheduling() { 

        Test.startTest(); 

        String schedule = '0 0 12 * * ?'; 

        System.schedule('TestBatchSchedule', schedule, new HubSpotScheduler()); 

        Test.stopTest(); 

         

        // Verify that the scheduled job is in the queue 

        CronTrigger ct = [ 

            SELECT Id, CronExpression, TimesTriggered FROM CronTrigger WHERE CronJobDetail.Name = 'TestBatchSchedule' LIMIT 1 

        ]; 

        System.assertNotEquals(null, ct, 'Scheduled job should be in the queue.'); 

    } 

}