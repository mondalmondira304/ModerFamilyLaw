@IsTest
private class TS_TrustBalanceSync_Batch_Test {

    private class TrustBalanceMock implements HttpCalloutMock {
        public HttpResponse respond(HttpRequest req) {
            Map<String, Object> body = new Map<String, Object>{
                'TrustAccountBalance' => new Map<String, Object>{
                    'Balance'        => 123.45,
                    'ReplenishBelow' => 100,
                    'ReplenishTo'    => 500
                }
            };
            HttpResponse res = new HttpResponse();
            res.setStatusCode(200);
            res.setBody(JSON.serialize(body));
            return res;
        }
    }

    @IsTest
    static void test_Execute_Upserts_Unique_Widget_Row() {

        Account client = new Account(
            RecordTypeId = '0124N000000X9ZgQAK',  // Person Account record type (keep your RT Id)
            LastName     = 'Test Client',
            PersonEmail  = 'client@example.com'
        );
        insert client;

        client.Timesolv_trustAccount_Id__c = 'TA-001';
        update client;

        Account opposing = new Account(Name = 'Opposing Party (Test)');
        insert opposing;

        MFL_Office__c office = new MFL_Office__c(Name = 'Test Office');
        insert office;

        Matters__c matter = new Matters__c(
            Name                = 'Trust Batch Test Matter',
            Status__c           = 'Open',
            Account__c          = client.Id,
            Client_Name__c      = client.Id,
            MFL_Office__c       = office.Id,
            Opposing_Party_a__c = opposing.Id,
            Case_Type__c        = 'Divorce w/out Children',
            Hire_Date__c        = Date.today().addDays(-1)   // <-- REQUIRED field on Matters__c
        );
        insert matter;

        matter = [
            SELECT Id,
                   Matter_ID_Full__c,
                   Account__c, Account__r.Id,
                   Account__r.Timesolv_trustAccount_Id__c,
                   Client_Name__c, Client_Name__r.Timesolv_trustAccount_Id__c
            FROM Matters__c
            WHERE Id = :matter.Id
        ];

        System.assertNotEquals(null, matter.Matter_ID_Full__c,
            'Formula field Matter_ID_Full__c should be populated.');

        System.assertEquals(0,
            [SELECT COUNT() FROM TS_Finance_Widget__c WHERE Matter__c = :matter.Id],
            'Widget should start empty.');

        Test.setMock(HttpCalloutMock.class, new TrustBalanceMock());

        Test.startTest();
        new TS_TrustBalanceSync_Batch()
            .execute(null, new List<Matters__c>{ matter });
        Test.stopTest();

        List<TS_Finance_Widget__c> widgets = [
            SELECT Matter__c, Matter_Id__c,
                   Timesolv_Trust_Balance__c,
                   Timesolv_Trust_Replenish_Below__c,
                   Timesolv_Trust_Replenish_To__c
            FROM TS_Finance_Widget__c
            WHERE Matter__c = :matter.Id
        ];

        System.assertEquals(1, widgets.size(), 'Widget row should have been created.');
        TS_Finance_Widget__c wid = widgets[0];
        System.assertEquals(matter.Id, wid.Matter__c);
        System.assertNotEquals(null, wid.Matter_Id__c);
        System.assertEquals(123.45, wid.Timesolv_Trust_Balance__c);
        System.assertEquals(100, wid.Timesolv_Trust_Replenish_Below__c);
        System.assertEquals(500, wid.Timesolv_Trust_Replenish_To__c);
    }

  @IsTest
static void test_Execute_UpdatesExistingWidget() {
    Test.setMock(HttpCalloutMock.class, new TrustBalanceMock());

    Account client = new Account(
        RecordTypeId = '0124N000000X9ZgQAK',
        LastName     = 'Update Client',
        PersonEmail  = 'update@example.com'
    );
    insert client;
    client.Timesolv_trustAccount_Id__c = 'TA-UPD';
    update client;

    Account opposing = new Account(Name = 'Opposing Party UPD');
    insert opposing;
    MFL_Office__c office = new MFL_Office__c(Name = 'UPD Office');
    insert office;

    Matters__c matter = new Matters__c(
        Name                = 'Update Path Matter',
        Status__c           = 'Open',
        Account__c          = client.Id,
        Client_Name__c      = client.Id,
        MFL_Office__c       = office.Id,
        Opposing_Party_a__c = opposing.Id,
        Case_Type__c        = 'Divorce w/out Children',
        Hire_Date__c        = Date.today().addDays(-1)
    );
    insert matter;

    matter = [
        SELECT Id,
               Matter_ID_Full__c,
               Account__c, Account__r.Id,
               Account__r.Timesolv_trustAccount_Id__c,
               Client_Name__c, Client_Name__r.Timesolv_trustAccount_Id__c
        FROM Matters__c
        WHERE Id = :matter.Id
    ];

    new TS_TrustBalanceSync_Batch().execute(null, new List<Matters__c>{ matter });

    Test.startTest();
    new TS_TrustBalanceSync_Batch().execute(null, new List<Matters__c>{ matter });
    Test.stopTest();

    TS_Finance_Widget__c after = [
        SELECT Timesolv_Trust_Balance__c,
               Timesolv_Trust_Replenish_Below__c,
               Timesolv_Trust_Replenish_To__c
        FROM TS_Finance_Widget__c
        WHERE Matter__c = :matter.Id
        LIMIT 1
    ];
    System.assertEquals(123.45, after.Timesolv_Trust_Balance__c);
    System.assertEquals(100,    after.Timesolv_Trust_Replenish_Below__c);
    System.assertEquals(500,    after.Timesolv_Trust_Replenish_To__c);
}

}