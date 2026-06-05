/**
 * AdobeFinalPdfDownloadSchedulable_Test
 *
 * Test coverage for AdobeFinalPdfDownloadSchedulable
 *
 * @author  Sanders
 * @date    2026-02-12
 */
@IsTest
private class AdobeFinalPdfDownloadSchedulable_Test {
    
    @IsTest
    static void testExecute_launchesBatch() {
        Test.startTest();
        
        AdobeFinalPdfDownloadSchedulable schedulable = new AdobeFinalPdfDownloadSchedulable();
        schedulable.execute(null);
        
        Test.stopTest();
        
        List<AsyncApexJob> jobs = [
            SELECT Id, ApexClass.Name
            FROM AsyncApexJob
            WHERE ApexClass.Name = 'AdobeFApdfBatch'
            AND CreatedDate = TODAY
        ];
        
        System.assertEquals(1, jobs.size());
    }
    
    @IsTest
    static void testSchedule_canBeScheduled() {
        Test.startTest();
        
        String cronExp = '0 0 * * * ?';
        String jobId = System.schedule('TEST_Adobe_Schedule', cronExp, new AdobeFinalPdfDownloadSchedulable());
        
        CronTrigger ct = [SELECT State FROM CronTrigger WHERE Id = :jobId];
        System.assertEquals('WAITING', ct.State);
        
        Test.stopTest();
        
        System.abortJob(jobId);
    }
    
    @IsTest
    static void testExecute_handlesExceptionAndLogsError() {
        Test.startTest();
        
        AdobeFinalPdfDownloadSchedulable.TEST_FORCE_EXCEPTION = true;
        
        AdobeFinalPdfDownloadSchedulable schedulable = new AdobeFinalPdfDownloadSchedulable();
        schedulable.execute(null);
        
        Test.stopTest();
        
        List<ErrorLog__c> errorLogs = [
            SELECT Id, ErrorMessage__c, Class_Name__c, Method_Name__c, ErrorType__c
            FROM ErrorLog__c
            WHERE Class_Name__c = 'AdobeFinalPdfDownloadSchedulable'
            AND CreatedDate = TODAY
        ];
        
        System.assertEquals(1, errorLogs.size());
        System.assertEquals('execute', errorLogs[0].Method_Name__c);
        System.assertEquals('System Error', errorLogs[0].ErrorType__c);
        System.assert(errorLogs[0].ErrorMessage__c.contains('Test exception'));
    }
}