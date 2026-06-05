@IsTest
private class TSFinanceWidgetController_Test {

    private static void setOpposingParty(Matters__c m, Id acctId) {
        Map<String, Schema.SObjectField> f = Schema.SObjectType.Matters__c.fields.getMap();
        if (f.containsKey('Opposing_Party__c')) {
            m.put('Opposing_Party__c', acctId);
        } else if (f.containsKey('Opposing_Party_a__c')) {
            m.put('Opposing_Party_a__c', acctId);
        }
    }

    @IsTest
    static void test_getWidgetForMatter_returns_row() {
        Account client = new Account(
            RecordTypeId = '0124N000000X9ZgQAK',
            LastName     = 'Widget Client',
            PersonEmail  = 'client@example.com'
        );
        insert client;

        Contact pc = [SELECT Id, Email FROM Contact WHERE AccountId = :client.Id LIMIT 1];
        if (String.isBlank(pc.Email)) {
            pc.Email = 'client@example.com';
            update pc;
        }

        Account opposing = new Account(Name = 'Opposing Party (Widget Test)');
        insert opposing;

        MFL_Office__c office = new MFL_Office__c(Name = 'Test Office 1');
        insert office;

        Matters__c matter = new Matters__c(
            Name          = 'Controller Widget Matter',
            Status__c     = 'Open',
            Account__c    = client.Id,
            MFL_Office__c = office.Id,
            Case_Type__c  = 'Divorce w/out Children',
            Hire_Date__c  = Date.today().addDays(-1)
        );
        setOpposingParty(matter, opposing.Id);
        insert matter;

        String key = ('UT-' + matter.Id).replace(' ', '').toUpperCase();

        TS_Finance_Widget__c wid = new TS_Finance_Widget__c(
            Matter__c                         = matter.Id,
            Matter_Id__c                      = key,
            Timesolv_Id__c                    = '200',
            Timesolv_Project_Id__c            = 'P-NEW',
            Timesolv_Total_WIP_Fees__c        = 110,
            Timesolv_Total_WIP_Expenses__c    = 11,
            Timesolv_Total_Fees__c            = 220,
            Timesolv_Total_Expenses__c        = 22,
            Timesolv_Total_WIP_Hours__c       = 33,
            Timesolv_Total_Worked_Hours__c    = 44,
            Timesolv_Total_Billable_Hours__c  = 55,
            Timesolv_Trust_Balance__c         = 66,
            Timesolv_Trust_Replenish_Below__c = 77,
            Timesolv_Trust_Replenish_To__c    = 88
        );
        insert wid;

        Test.startTest();
        TS_Finance_Widget__c got = TSFinanceWidgetController.getWidgetForMatter(matter.Id);
        Test.stopTest();

        System.assertNotEquals(null, got, 'Widget should not be null');
        System.assertEquals(wid.Id, got.Id, 'Should return the widget for the Matter');
        System.assertEquals(matter.Id, got.Matter__c);
        System.assertEquals('P-NEW', got.Timesolv_Project_Id__c);
        System.assertEquals(220, got.Timesolv_Total_Fees__c);
        System.assertEquals(66, got.Timesolv_Trust_Balance__c);
        System.assertEquals(77, got.Timesolv_Trust_Replenish_Below__c);
        System.assertEquals(88, got.Timesolv_Trust_Replenish_To__c);
    }

    @IsTest
    static void test_getWidgetForMatter_returns_null_when_none() {
        Account a = new Account(
            RecordTypeId = '0124N000000X9ZgQAK',
            LastName     = 'No Widget Client',
            PersonEmail  = 'nowidget@example.com'
        );
        insert a;

        Contact pc = [SELECT Id, Email FROM Contact WHERE AccountId = :a.Id LIMIT 1];
        if (String.isBlank(pc.Email)) {
            pc.Email = 'nowidget@example.com';
            update pc;
        }

        MFL_Office__c office = new MFL_Office__c(Name = 'Test Office 2');
        insert office;

        Matters__c m = new Matters__c(
            Name          = 'No Widget Matter',
            Status__c     = 'Open',
            Account__c    = a.Id,
            MFL_Office__c = office.Id,
            Case_Type__c  = 'Divorce w/out Children',
            Hire_Date__c  = Date.today().addDays(-1)
        );
        insert m;

        Test.startTest();
        TS_Finance_Widget__c result = TSFinanceWidgetController.getWidgetForMatter(m.Id);
        Test.stopTest();

        System.assertEquals(null, result, 'Should return null when no widget exists for the Matter');
    }

    @IsTest
    static void test_getWidgetForMatter_returns_null_when_matterId_null() {
        Test.startTest();
        TS_Finance_Widget__c result = TSFinanceWidgetController.getWidgetForMatter(null);
        Test.stopTest();

        System.assertEquals(null, result, 'Should return null when matterId is null');
    }
}