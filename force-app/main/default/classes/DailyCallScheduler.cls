public class DailyCallScheduler implements Schedulable {
    public void execute(SchedulableContext sc) {
        // Enqueue the daily job
        System.enqueueJob(new CallQueueable('daily'));

        // Enqueue the monthly job
        System.enqueueJob(new CallQueueable('monthly'));

        // Enqueue the detail job
        System.enqueueJob(new CallQueueable('detail'));
    }
}