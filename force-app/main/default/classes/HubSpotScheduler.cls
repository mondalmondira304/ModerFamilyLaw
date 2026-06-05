public class HubSpotScheduler implements Schedulable {
    public void execute(SchedulableContext sc) {
        HubSpotBatch batch = new HubSpotBatch();
        Database.executeBatch(batch);
    }
}