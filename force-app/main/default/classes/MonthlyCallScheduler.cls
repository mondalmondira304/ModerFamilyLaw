public class MonthlyCallScheduler implements Schedulable {
    public void execute(SchedulableContext sc) {
        // Enqueue the queueable job with "monthly" as the call type
        System.enqueueJob(new CallQueueable('monthly'));
    }
}