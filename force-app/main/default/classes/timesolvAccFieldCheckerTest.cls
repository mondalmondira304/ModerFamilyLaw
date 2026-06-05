@IsTest(SeeAllData=false)
private class timesolvAccFieldCheckerTest {

    @TestSetup
    static void setupTestData() {
        insert new Account(
            Name = 'NoTrustIdAccount'
        );
        insert new Account(
            Name                     = 'WithTrustIdAccount',
            Invoice_Retainer_Id__c   = 'TRUST12345'
        );
        insert new Account(
            Name                    = 'GoldAccount',
            Credit_Decision__c      = 'Gold - 0% Retainer'
        );
    }

    @IsTest
    static void testNullAccountId() {
        timesolvAccFieldChecker.InvoiceRetainerResult result =
            timesolvAccFieldChecker.getInvoiceRetainerStatus(null);
        System.assertEquals(
            null,
            result.invoiceRetainerId,
            'Null Account should return null invoiceRetainerId'
        );
        System.assertEquals(
    false,
    result.isGold == true,
    'Null Account should return isGold = false'
);

    }

    @IsTest
    static void testAccountWithoutTrustIdOrGold() {
        Account a = [
            SELECT Id
              FROM Account
             WHERE Name = 'NoTrustIdAccount'
             LIMIT 1
        ];
        Test.startTest();
            timesolvAccFieldChecker.InvoiceRetainerResult result =
                timesolvAccFieldChecker.getInvoiceRetainerStatus(a.Id);
        Test.stopTest();
        System.assertEquals(
            null,
            result.invoiceRetainerId,
            'Account with no Invoice_Retainer_Id__c should return null'
        );
        System.assertEquals(
            false,
            result.isGold,
            'Account with no Gold credit decision should return isGold = false'
        );
    }

    @IsTest
    static void testAccountWithTrustId() {
        Account a = [
            SELECT Id
              FROM Account
             WHERE Name = 'WithTrustIdAccount'
             LIMIT 1
        ];
        Test.startTest();
            timesolvAccFieldChecker.InvoiceRetainerResult result =
                timesolvAccFieldChecker.getInvoiceRetainerStatus(a.Id);
        Test.stopTest();
        System.assertEquals(
            'TRUST12345',
            result.invoiceRetainerId,
            'Should return the populated Invoice_Retainer_Id__c value'
        );
        System.assertEquals(
            false,
            result.isGold,
            'Should return isGold = false for non-gold'
        );
    }

    @IsTest
    static void testAccountWithGold() {
        Account a = [
            SELECT Id
              FROM Account
             WHERE Name = 'GoldAccount'
             LIMIT 1
        ];
        Test.startTest();
            timesolvAccFieldChecker.InvoiceRetainerResult result =
                timesolvAccFieldChecker.getInvoiceRetainerStatus(a.Id);
        Test.stopTest();
        System.assertEquals(
            null,
            result.invoiceRetainerId,
            'Gold account should have no invoiceRetainerId'
        );
        System.assertEquals(
            true,
            result.isGold,
            'Gold account should return isGold = true'
        );
    }
}