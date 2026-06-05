@IsTest
private class WaitingForCreditResultServiceTest {
    /**
     * @description Creates reusable test Accounts.
     *  - aFull: has all custom fields populated for positive-path assertions
     *  - aNameOnly: only Name populated to exercise null/empty value handling
     */
    @testSetup
    static void setupData() {
        // Full record with all fields populated
        Account aFull = new Account(
            Name = 'Test Client Full',
            Credit_Decision__c = 'Full Retainer',
            Credit_Report_Link__c = 'https://example.com/report/ABC123',
            Quoted_Retainer__c = 2500,
            Quoted_Retainer_Amount__c = 1500
        );

        // Minimal record to verify graceful handling of nulls
        Account aNameOnly = new Account(
            Name = 'Test Client Minimal'
        );

        insert new List<Account>{ aFull, aNameOnly };
    }

    /**
     * @description Verifies getDecisionWithLink returns the populated wrapper.
     */
    @IsTest
    static void test_getDecisionWithLink_full() {
        Account a = [
            SELECT Id, Name, Credit_Decision__c, Credit_Report_Link__c,
                   Quoted_Retainer__c, Quoted_Retainer_Amount__c
            FROM Account
            WHERE Name = 'Test Client Full'
            LIMIT 1
        ];

        WaitingForCreditResultService.DecisionResult res =
            WaitingForCreditResultService.getDecisionWithLink(a.Id);

        System.assertNotEquals(null, res, 'Result wrapper should not be null');
        System.assertEquals('Full Retainer', res.creditDecision);
        System.assertEquals('https://example.com/report/ABC123', res.reportLink);
        System.assertEquals(2500, res.quotedRetainer);
        System.assertEquals(1500, res.reducedRetainer);
        System.assertEquals('Test Client Full', res.accountName);
    }

    /**
     * @description Verifies getDecisionWithLink with null Id returns an empty wrapper (no exception).
     */
    @IsTest
    static void test_getDecisionWithLink_nullId() {
        WaitingForCreditResultService.DecisionResult res =
            WaitingForCreditResultService.getDecisionWithLink(null);

        System.assertNotEquals(null, res, 'Result wrapper should be constructed');
        System.assertEquals(null, res.creditDecision);
        System.assertEquals(null, res.reportLink);
        System.assertEquals(null, res.quotedRetainer);
        System.assertEquals(null, res.reducedRetainer);
        System.assertEquals(null, res.accountName);
    }

    /**
     * @description Verifies getCreditDecision returns the field value.
     */
    @IsTest
    static void test_getCreditDecision_value() {
        Id acctId = [
            SELECT Id FROM Account WHERE Name = 'Test Client Full' LIMIT 1
        ].Id;

        String decision = WaitingForCreditResultService.getCreditDecision(acctId);
        System.assertEquals('Full Retainer', decision, 'Credit decision should match');
    }

    /**
     * @description Verifies getCreditDecision with null Id returns null.
     */
    @IsTest
    static void test_getCreditDecision_nullId() {
        String decision = WaitingForCreditResultService.getCreditDecision(null);
        System.assertEquals(null, decision, 'Null accountId should return null');
    }

    /**
     * @description Verifies getDecisionAsMap returns a map with expected keys/values when fields are populated.
     */
    @IsTest
    static void test_getDecisionAsMap_full() {
        Account a = [
            SELECT Id FROM Account WHERE Name = 'Test Client Full' LIMIT 1
        ];

        Map<String, Object> outMap = WaitingForCreditResultService.getDecisionAsMap(a.Id);

        System.assertNotEquals(null, outMap, 'Map should not be null');
        System.assertEquals('Full Retainer', (String) outMap.get('creditDecision'));
        System.assertEquals('https://example.com/report/ABC123', (String) outMap.get('reportLink'));
        System.assertEquals(2500, (Decimal) outMap.get('quotedRetainer'));
        System.assertEquals(1500, (Decimal) outMap.get('reducedRetainer'));
        System.assertEquals('Test Client Full', (String) outMap.get('accountName'));
    }

    /**
     * @description Verifies getDecisionAsMap on an Account with only Name set.
     * Confirms keys exist and nulls are handled safely when fields are unset.
     */
    @IsTest
    static void test_getDecisionAsMap_minimal() {
        Account a = [
            SELECT Id FROM Account WHERE Name = 'Test Client Minimal' LIMIT 1
        ];

        Map<String, Object> outMap = WaitingForCreditResultService.getDecisionAsMap(a.Id);

        System.assertNotEquals(null, outMap, 'Map should not be null');
        System.assertEquals('Test Client Minimal', (String) outMap.get('accountName'));
        System.assert(outMap.containsKey('creditDecision'),
            'Map should contain creditDecision key even if value is null');
        System.assert(outMap.containsKey('reportLink'),
            'Map should contain reportLink key even if value is null');
        System.assert(outMap.containsKey('quotedRetainer'),
            'Map should contain quotedRetainer key even if value is null');
        System.assert(outMap.containsKey('reducedRetainer'),
            'Map should contain reducedRetainer key even if value is null');
    }
}