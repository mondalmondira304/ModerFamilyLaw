public with sharing class timesolvAccFieldChecker {
    public class InvoiceRetainerResult {
        @AuraEnabled public String invoiceRetainerId;
        @AuraEnabled public Boolean isGold;
    }

    @AuraEnabled
    public static InvoiceRetainerResult getInvoiceRetainerStatus(Id accountId) {
        System.debug('getInvoiceRetainerStatus called with accountId=' + accountId);
        InvoiceRetainerResult result = new InvoiceRetainerResult();

        if (accountId == null) {
            System.debug(' → no accountId, returning');
            return result;
        }

        List<Account> accList = [
            SELECT Invoice_Retainer_Id__c, Credit_Decision__c
            FROM Account
            WHERE Id = :accountId
            LIMIT 1
        ];
        if (accList.isEmpty()) {
            System.debug(' → no Account found, returning');
            return result;
        }

        Account acc = accList[0];
        result.invoiceRetainerId = acc.Invoice_Retainer_Id__c;
        result.isGold = acc.Credit_Decision__c != null &&
            acc.Credit_Decision__c.trim().toLowerCase() == 'gold - 0% retainer'.toLowerCase();

        System.debug(' → returning InvoiceRetainerResult: ' +
            'invoiceRetainerId=' + result.invoiceRetainerId +
            ', isGold=' + result.isGold);
        return result;
    }
}