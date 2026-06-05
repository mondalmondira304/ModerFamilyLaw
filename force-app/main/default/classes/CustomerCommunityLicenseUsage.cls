public without sharing class CustomerCommunityLicenseUsage {

    private static final String LICENSE_NAME = 'Customer Community';

    @TestVisible static Boolean testMode = false;
    @TestVisible static UserLicense testUL;
    @TestVisible static Map<Boolean, Integer> testCounts;

    public static void run() {
        runWithDate(Date.today());
    }

    @TestVisible
    static void runWithDate(Date snapDate) {
        UserLicense ul = getUserLicense();

        Integer totalLic = ul == null ? 0 : (ul.TotalLicenses == null ? 0 : ul.TotalLicenses);
        Integer usedLic  = ul == null ? 0 : (ul.UsedLicenses  == null ? 0 : ul.UsedLicenses);

        Map<Boolean, Integer> byActive = getUserCountsByActive();
        Integer activeUsers   = byActive.get(true)  == null ? 0 : byActive.get(true);
        Integer inactiveUsers = byActive.get(false) == null ? 0 : byActive.get(false);

        Portal_License_Usage__c row = new Portal_License_Usage__c(
            Snapshot_Date__c  = snapDate,
            License_Name__c   = LICENSE_NAME,
            Total_License__c          = totalLic,
            Used_License__c           = usedLic,
            Active_Users__c   = activeUsers,
            Inactive_Users__c = inactiveUsers
        );

        insert row; 
    }

    @TestVisible
    private static UserLicense getUserLicense() {
        if (testMode && testUL != null) return testUL;
        List<UserLicense> rows = [
            SELECT Id, Name, TotalLicenses, UsedLicenses, Status
            FROM UserLicense
            WHERE Name = :LICENSE_NAME
            LIMIT 1
        ];
        return rows.isEmpty() ? null : rows[0];
    }

    @TestVisible
    private static Map<Boolean, Integer> getUserCountsByActive() {
        if (testMode && testCounts != null) {
            // ensure both keys exist
            if (!testCounts.containsKey(true))  testCounts.put(true, 0);
            if (!testCounts.containsKey(false)) testCounts.put(false, 0);
            return testCounts;
        }

        Map<Boolean,Integer> res = new Map<Boolean,Integer>{ true=>0, false=>0 };
        for (AggregateResult ar : [
            SELECT IsActive, COUNT(Id) cnt
            FROM User
            WHERE Profile.UserLicense.Name = :LICENSE_NAME
            GROUP BY IsActive
        ]) {
            res.put( (Boolean)ar.get('IsActive'), (Integer)ar.get('cnt') );
        }
        return res;
    }

    public class Scheduler implements Schedulable {
        public void execute(SchedulableContext sc) {
            CustomerCommunityLicenseUsage.run();
        }
    }

    @InvocableMethod(label='Run Customer Community License Snapshot Now')
    public static void runNow(List<String> ignore) {
        CustomerCommunityLicenseUsage.run();
    }
}