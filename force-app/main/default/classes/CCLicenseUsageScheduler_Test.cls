@IsTest
private class CCLicenseUsageScheduler_Test {

    @IsTest
    static void testSchedulerExecute_insertsRow() {
        // Enable test hooks in the main class
        CustomerCommunityLicenseUsage.testMode = true;

        // Mock a UserLicense via JSON (fields are not writeable directly)
        CustomerCommunityLicenseUsage.testUL =
            (UserLicense) JSON.deserialize(
                '{"Name":"Customer Community","TotalLicenses":10,"UsedLicenses":7,"Status":"Active"}',
                UserLicense.class
            );

        // Mock active/inactive user counts
        CustomerCommunityLicenseUsage.testCounts = new Map<Boolean, Integer>{
            true => 6,
            false => 1
        };

        Test.startTest();
        new CCLicenseUsageScheduler().execute(null);
        Test.stopTest();

        // Verify that a Portal_License_Usage__c record was created
        Portal_License_Usage__c rec = [
            SELECT Id, Snapshot_Date__c, License_Name__c,
                   Total_License__c, Used_License__c,
                   Active_Users__c, Inactive_Users__c, CreatedDate
            FROM Portal_License_Usage__c
            ORDER BY CreatedDate DESC
            LIMIT 1
        ];

        System.assertEquals(Date.today(), rec.Snapshot_Date__c, 'Snapshot date mismatch');
        System.assertEquals('Customer Community', rec.License_Name__c, 'License name mismatch');
        System.assertEquals(10, rec.Total_License__c, 'Total licenses mismatch');
        System.assertEquals(7,  rec.Used_License__c,  'Used licenses mismatch');
        System.assertEquals(6,  rec.Active_Users__c,  'Active users mismatch');
        System.assertEquals(1,  rec.Inactive_Users__c,'Inactive users mismatch');
    }

    @IsTest
    static void testSystemSchedule_returnsId() {
        Test.startTest();
        String jobId = System.schedule(
            'CCLicenseUsage@09:00',
            '0 0 9 * * ?',
            new CCLicenseUsageScheduler()
        );
        Test.stopTest();

        System.assertNotEquals(null, jobId, 'Expected a ScheduledApex job Id');
    }
}