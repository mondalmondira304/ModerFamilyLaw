/**
 * AdobeFinalPdfDownloadSchedulable
 *
 * Schedulable wrapper for AdobeFApdfBatch.
 * Runs every 15 minutes to process All Signed fee agreements.
 *
 * @author  Sanders
 * @date    2026-02-12
 */
public class AdobeFinalPdfDownloadSchedulable implements Schedulable {
    
    private static final String CLASS_NAME = 'AdobeFinalPdfDownloadSchedulable';
    
    @TestVisible private static Boolean TEST_FORCE_EXCEPTION = false;
    
    public void execute(SchedulableContext sc) {
        try {
            if (TEST_FORCE_EXCEPTION) {
                throw new CalloutException('Test exception for coverage');
            }
            
            AdobeFApdfBatch.runBatch();
        } catch (Exception e) {
            ErrorLog__c errorLog = new ErrorLog__c(
                Class_Name__c = CLASS_NAME,
                Method_Name__c = 'execute',
                ErrorType__c = 'System Error',
                Integration_Name__c = 'Adobe FA Portal',
                ErrorMessage__c = 'Failed to execute batch: ' + e.getMessage(),
                ErrorStackTrace__c = e.getStackTraceString()
            );
            
            try {
                insert errorLog;
            } catch (Exception logError) {
                System.debug(
                    LoggingLevel.ERROR,
                    'Failed to log scheduler error: ' + logError.getMessage()
                );
            }
        }
    }
}