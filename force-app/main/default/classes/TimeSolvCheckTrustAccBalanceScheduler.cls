/**
 * @description Scheduler for the TimeSolvCheckTrustAccBalanceBatch job
 *              Invokes the batch on a configurable cadence
 * @author Sanders
 * @date    2025-05-02
 */
global class TimeSolvCheckTrustAccBalanceScheduler implements Schedulable {
    /**
     * @description Scheduler entry point for trust account balance batch
     * @param context The SchedulableContext provided by the platform
     */
    global void execute(SchedulableContext context) {
        // Pull the batch size constant from the batch class
        Integer batchSize = TimeSolvCheckTrustAccBalanceBatch.SAFE_BATCH_SIZE;

        try {
            // Kick off the batch job
            Id jobId = Database.executeBatch(
                new TimeSolvCheckTrustAccBalanceBatch(),
                batchSize
            );

            // Log where to find it in the AsyncApexJob table
            System.debug(
                LoggingLevel.INFO,
                '[Scheduler] Launched TimeSolvCheckTrustAccBalanceBatch ' +
                'with batchSize=' + batchSize +
                ' | jobId=' + jobId
            );
        } catch (Exception ex) {
            // Surface any scheduling failure
            System.debug(
                LoggingLevel.ERROR,
                '[Scheduler] Failed to launch batch: ' + ex.getMessage()
            );
            throw ex;
        }
    }
}