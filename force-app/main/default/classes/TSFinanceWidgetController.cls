public with sharing class TSFinanceWidgetController {

    @AuraEnabled(cacheable=true)
    public static TS_Finance_Widget__c getWidgetForMatter(Id matterId) {
        if (matterId == null) return null;

        List<TS_Finance_Widget__c> rows = [
            SELECT Id, Matter__c,
                   LastModifiedDate,
                   Timesolv_Id__c,
                   Timesolv_Project_Id__c,
                   Timesolv_Total_WIP_Fees__c,
                   Timesolv_Total_WIP_Expenses__c,
                   Timesolv_Total_Fees__c,
                   Timesolv_Total_Expenses__c,
                   Timesolv_Total_WIP_Hours__c,
                   Timesolv_Total_Worked_Hours__c,
                   Timesolv_Total_Billable_Hours__c,
                   Timesolv_Trust_Balance__c,
                   Timesolv_Trust_Replenish_Below__c,
                   Timesolv_Trust_Replenish_To__c
            FROM TS_Finance_Widget__c
            WHERE Matter__c = :matterId
            ORDER BY LastModifiedDate DESC
            LIMIT 1
        ];

        return rows.isEmpty() ? null : rows[0];
    }
}