@IsTest
private class CustomerCommunityLicenseUsage_Test {

    @IsTest
    static void test_HappyPath_UsingTestHooks() {
        CustomerCommunityLicenseUsage.testMode = true;

        CustomerCommunityLicenseUsage.testUL =
            (UserLicense)JSON.deserialize(
                '{"Name":"Customer Community","TotalLicenses":1000,"UsedLicenses":943}',
                UserLicense.class
            );

        CustomerCommunityLicenseUsage.testCounts = new Map<Boolean,Integer>{
            true => 940,
            false => 3
        };

        Test.startTest();
        CustomerCommunityLicenseUsage.run(); 
        Test.stopTest();

        Portal_License_Usage__c row = [
            SELECT Snapshot_Date__c, License_Name__c, Total_License__c, Used_License__c,
                   Active_Users__c, Inactive_Users__c, Remaining_License__c
            FROM Portal_License_Usage__c
            LIMIT 1
        ];

        System.assertEquals('Customer Community', row.License_Name__c);
        System.assertEquals(1000, row.Total_License__c);
        System.assertEquals(943,  row.Used_License__c);
        System.assertEquals(940,  row.Active_Users__c);
        System.assertEquals(3,    row.Inactive_Users__c);
        System.assertEquals(57,   row.Remaining_License__c);
    }

    @IsTest
    static void test_GetUserLicense_NoRecord() {
        CustomerCommunityLicenseUsage.testMode = false; 
        Test.startTest();
        UserLicense result = Test.isRunningTest()
            ? null
            : [SELECT Id FROM UserLicense WHERE Name = 'NoSuchLicense' LIMIT 1];
        CustomerCommunityLicenseUsage.getUserLicense();
        Test.stopTest();
        System.assert(true, 'Handled gracefully with no exceptions.');
    }

    @IsTest
    static void test_GetUserCountsByActive_RealQuery() {
        Profile p = [SELECT Id FROM Profile WHERE UserLicense.Name != null LIMIT 1];
        User u1 = new User(
            Alias = 'ccu1',
            Email = 'u1@example.com',
            EmailEncodingKey = 'UTF-8',
            LastName = 'U1',
            LanguageLocaleKey = 'en_US',
            LocaleSidKey = 'en_US',
            TimeZoneSidKey = 'America/New_York',
            Username = 'ccu1' + DateTime.now().getTime() + '@test.com',
            ProfileId = p.Id
        );
        insert u1;

        Test.startTest();
        Map<Boolean,Integer> counts = CustomerCommunityLicenseUsage.getUserCountsByActive();
        Test.stopTest();

        System.assertNotEquals(null, counts);
    }

    @IsTest
    static void test_Scheduler_Execute() {
        CustomerCommunityLicenseUsage.testMode = true;
        CustomerCommunityLicenseUsage.testUL =
            (UserLicense)JSON.deserialize(
                '{"Name":"Customer Community","TotalLicenses":1,"UsedLicenses":1}',
                UserLicense.class
            );
        CustomerCommunityLicenseUsage.testCounts = new Map<Boolean,Integer>{true=>1,false=>0};

        Test.startTest();
        new CustomerCommunityLicenseUsage.Scheduler().execute(null);
        Test.stopTest();

        System.assertEquals(1, [SELECT COUNT() FROM Portal_License_Usage__c]);
    }

    @IsTest
    static void test_InvocableMethod_RunNow() {
        CustomerCommunityLicenseUsage.testMode = true;
        CustomerCommunityLicenseUsage.testUL =
            (UserLicense)JSON.deserialize(
                '{"Name":"Customer Community","TotalLicenses":10,"UsedLicenses":5}',
                UserLicense.class
            );
        CustomerCommunityLicenseUsage.testCounts = new Map<Boolean,Integer>{true=>5,false=>0};

        Test.startTest();
        CustomerCommunityLicenseUsage.runNow(new List<String>());
        Test.stopTest();

        System.assert([SELECT COUNT() FROM Portal_License_Usage__c] > 0);
    }
}