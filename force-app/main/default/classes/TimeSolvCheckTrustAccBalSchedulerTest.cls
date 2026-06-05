/**
 * @name        TimeSolvCheckTrustAccBalanceSchedulerTest
 * @description Verifies that the scheduler enqueues the
 *              TimeSolvCheckTrustAccBalanceBatch job without throwing,
 *              using an HTTP mock to avoid real call-outs.
 * @author      Sanders
 * @since       2025-05-02
 */
@IsTest
private class TimeSolvCheckTrustAccBalSchedulerTest {

    /** Simple mock that satisfies any HTTP call the batch may perform. */
    private class DummyTrustBalanceMock implements HttpCalloutMock {
        public HTTPResponse respond(HTTPRequest req) {
            HttpResponse res = new HttpResponse();
            res.setStatusCode(200);
            // Minimal JSON payload the batch can safely parse
            res.setBody('{"balances":[]}'); 
            return res;
        }
    }

    /**
     * Ensures that System.schedule → Scheduler.execute → Database.executeBatch
     * runs end-to-end and leaves an AsyncApexJob row for the batch.  
     */
    @IsTest
    static void schedulerLaunchesBatch() {
        // -- Arrange --
        // Register the mock for every call-out the batch makes.
        Test.setMock(HttpCalloutMock.class, new DummyTrustBalanceMock());

        // Valid cron: 0 s, 0 min, 0 hr, 15 May 2050, any day-of-week.
        String cron = '0 0 0 15 5 ? 2050';

        // -- Act --
        Test.startTest();
        System.schedule('UT_TimeSolvBalanceSched', cron,
                        new TimeSolvCheckTrustAccBalanceScheduler());
        Test.stopTest();     // Forces all async work to finish in the test context.

        // -- Assert --
        List<AsyncApexJob> jobs = [
            SELECT Id, Status
            FROM   AsyncApexJob
            WHERE  JobType      = 'BatchApex'
            AND    ApexClass.Name = 'TimeSolvCheckTrustAccBalanceBatch'
            LIMIT  1
        ];
        System.assert(!jobs.isEmpty(),
            'Scheduler should enqueue TimeSolvCheckTrustAccBalanceBatch.');
    }
}