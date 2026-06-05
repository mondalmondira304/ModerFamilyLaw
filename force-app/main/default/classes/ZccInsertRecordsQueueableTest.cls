/**
 * @testcase  ZccInsertRecordsQueueableTest
 * @author    Sanders
 * @date      2025-05-03
 */
@IsTest(seeAllData = false)
private class ZccInsertRecordsQueueableTest {

    /* ------------------------------------------------------------
       Helpers
       ------------------------------------------------------------ */
    private static Zcc_Queue_Call_Details__c buildDetail(String consumer, String engagementId) {
        return new Zcc_Queue_Call_Details__c(
            Name               = 'Detail-' + engagementId,
            Consumer_Number__c = consumer,
            Engagement_Id__c   = engagementId
        );
    }

    private static Id createSummary() {
        Zcc_Call_Queue_Summary__c s = new Zcc_Call_Queue_Summary__c(Name = 'Unit-Test Summary');
        insert s;
        return s.Id;
    }

    /* ------------------------------------------------------------
       1) Happy-path – insert + lookup + pagination
       ------------------------------------------------------------ */
    @IsTest
    static void testExecute_withRecordsAndToken() {
        /* ❶ Account phone MUST be in already-normalized 10-digit form
              because production code compares Phone == '3035551212'  */
        Account acc = new Account(Name = 'Test Acc', Phone = '3035551212');
        insert acc;

        String engagementId = 'E' + String.valueOf(Math.random()).substring(2, 8);
        List<Zcc_Queue_Call_Details__c> details = new List<Zcc_Queue_Call_Details__c>{
            buildDetail('303-555-1212', engagementId)   // formatted value is okay here
        };

        ZccInsertRecordsQueueable job = new ZccInsertRecordsQueueable(
            details,
            createSummary(),
            'NEXT_TOKEN',
            'DUMMY_ACCESS',
            '2025-05-01',
            '2025-05-02'
        );

        Test.startTest();
            System.enqueueJob(job);
        Test.stopTest();

        /* ───────────────────────────────
           Assertions
           ─────────────────────────────── */
        Zcc_Queue_Call_Details__c inserted =
            [SELECT Call_Summary__c, Account_Lookup__c
               FROM Zcc_Queue_Call_Details__c
              WHERE Engagement_Id__c = :engagementId
              LIMIT 1];

        System.assertNotEquals(null, inserted.Id,  'Detail record missing');
        System.assertEquals(acc.Id, inserted.Account_Lookup__c,
            'Account should have been linked via phone match');
        System.assertNotEquals(null, inserted.Call_Summary__c,
            'Call_Summary__c should be populated');
    }

    /* ------------------------------------------------------------
       2) Empty-list + no token – early-exit branch
       ------------------------------------------------------------ */
    @IsTest
    static void testExecute_noRecordsNoToken() {
        ZccInsertRecordsQueueable job = new ZccInsertRecordsQueueable(
            new List<Zcc_Queue_Call_Details__c>(),
            createSummary(),
            null,
            null,
            null,
            null
        );

        Test.startTest();
            System.enqueueJob(job);
        Test.stopTest();

        Integer detailCount = [SELECT COUNT() FROM Zcc_Queue_Call_Details__c];
        System.assertEquals(
            0, detailCount,
            'No detail records should exist when the input list is empty'
        );
    }
}