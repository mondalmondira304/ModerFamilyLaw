public without sharing class CCLicenseUsageScheduler implements Schedulable {
    public void execute(SchedulableContext sc) {
        CustomerCommunityLicenseUsage.run();
    }
}