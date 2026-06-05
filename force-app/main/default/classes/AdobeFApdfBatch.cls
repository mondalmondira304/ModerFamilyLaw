public without sharing class AdobeFApdfBatch
    implements Database.Batchable<SObject>, Database.Stateful, Database.AllowsCallouts {
    
    public static final Integer SAFE_SCOPE_SIZE             = 1;
    public static final Integer DEFAULT_MAX_RECORDS_PER_RUN = 200;
    private static final String CLASS_NAME = 'AdobeFApdfBatch';
    
    private Integer maxRecords;
    private String prefetchedToken;
    private List<ErrorLog__c> errorLogs = new List<ErrorLog__c>();
    
    @TestVisible private static Integer TEST_PROCESSED_COUNT = 0;
    @TestVisible private static Boolean TEST_FORCE_TRY_EXCEPTION = false;
    
    public AdobeFApdfBatch() {
        this(DEFAULT_MAX_RECORDS_PER_RUN, null);
    }
    
    public AdobeFApdfBatch(Integer maxRecords) {
        this(maxRecords, null);
    }
    
    public AdobeFApdfBatch(Integer maxRecords, String prefetchedToken) {
        this.maxRecords = (maxRecords != null && maxRecords > 0)
            ? maxRecords
            : DEFAULT_MAX_RECORDS_PER_RUN;
        this.prefetchedToken = prefetchedToken;
    }
    
    public static Id runBatch() {
        return Database.executeBatch(
            new AdobeFApdfBatch(),
            SAFE_SCOPE_SIZE
        );
    }
    
    public static Id runBatch(Integer maxRecords) {
        return Database.executeBatch(
            new AdobeFApdfBatch(maxRecords),
            SAFE_SCOPE_SIZE
        );
    }
    
    public static Id runBatch(Integer maxRecords, String prefetchedToken) {
        return Database.executeBatch(
            new AdobeFApdfBatch(maxRecords, prefetchedToken),
            SAFE_SCOPE_SIZE
        );
    }
    
    public Database.QueryLocator start(Database.BatchableContext bc) {
        String soql =
            'SELECT Id, Name, FA_Portal_AgreementId__c, FA_Portal_Agreement_Status__c ' +
            'FROM Account ' +
            'WHERE FA_Portal_AgreementId__c != null ' +
            'AND FA_Portal_AgreementId__c != \'\' ' +
            'AND FA_Portal_Agreement_Status__c = \'All Signed\' ' +
            'ORDER BY LastModifiedDate DESC ' +
            'LIMIT ' + String.valueOf(this.maxRecords);
        return Database.getQueryLocator(soql);
    }
    
    public void execute(Database.BatchableContext bc, List<Account> scope) {
        if (scope == null || scope.isEmpty()) return;
        
        // Use prefetched token if available; fall back to live retrieval
        String token;
        try {
            if (TEST_FORCE_TRY_EXCEPTION) {
                throw new CalloutException('Forced exception for test coverage');
            }
            token = String.isNotBlank(this.prefetchedToken)
                ? this.prefetchedToken
                : AdobeSignTokenUtil.getAccessToken();
        } catch (Exception e) {
            logError(e, null, null);
            flushErrorLogs();
            return;
        }
        
        if (String.isBlank(token)) {
            logError(
                new AdobeFinalAgreementDownloader.DownloadException('Access token retrieval failed'),
                null, null
            );
            flushErrorLogs();
            return;
        }
        
        // PHASE 1: CALLOUTS ONLY - Download all PDFs
        Map<Id, Blob> pdfsByAccountId = new Map<Id, Blob>();
        Map<Id, String> namesByAccountId = new Map<Id, String>();
        Map<Id, String> agreementIdsByAccountId = new Map<Id, String>();
        
        for (Account a : scope) {
            if (String.isBlank(a.FA_Portal_AgreementId__c)) continue;
            
            try {
                Blob finalPdf = AdobeFinalAgreementDownloader.downloadSignedPdf(
                    a.FA_Portal_AgreementId__c, 
                    token
                );
                
                if (finalPdf == null || finalPdf.size() == 0) {
                    throw new AdobeFinalAgreementDownloader.DownloadException(
                        'PDF download returned empty blob'
                    );
                }
                
                // Store successful downloads
                pdfsByAccountId.put(a.Id, finalPdf);
                namesByAccountId.put(a.Id, buildAgreementName(a));
                agreementIdsByAccountId.put(a.Id, a.FA_Portal_AgreementId__c);
                
            } catch (Exception e) {
                logError(e, a.Id, a.FA_Portal_AgreementId__c);
            }
        }
        
        // PHASE 2: DML ONLY - Save PDFs and update accounts
        List<Account> accountsToUpdate = new List<Account>();
        
        for (Id accountId : pdfsByAccountId.keySet()) {
            try {
                AdobeAgreementFileSaver.saveFinalPdf(
                    pdfsByAccountId.get(accountId),
                    accountId,
                    agreementIdsByAccountId.get(accountId),
                    namesByAccountId.get(accountId)
                );
                
                accountsToUpdate.add(new Account(
                    Id = accountId,
                    FA_Portal_Agreement_Status__c = 'FA_Downloaded'
                ));
                
                TEST_PROCESSED_COUNT++;
                
            } catch (Exception e) {
                logError(e, accountId, agreementIdsByAccountId.get(accountId));
            }
        }
        
        // Update all successful accounts
        if (!accountsToUpdate.isEmpty()) {
            try {
                update accountsToUpdate;
            } catch (Exception e) {
                logError(e, null, null);
            }
        }
        
        // Flush error logs for this execute cycle
        flushErrorLogs();
    }
    
    public void finish(Database.BatchableContext bc) {
    }
    
    
    private void flushErrorLogs() {
        if (!errorLogs.isEmpty()) {
            try {
                insert errorLogs;
            } catch (Exception e) {
                System.debug(LoggingLevel.ERROR, 
                    'Failed to insert error logs: ' + e.getMessage());
            }
            errorLogs.clear();
        }
    }
    
    private void logError(Exception e, Id accountId, String agreementId) {
        ErrorLog__c errorLog = new ErrorLog__c(
            Class_Name__c = CLASS_NAME,
            Method_Name__c = 'execute',
            ErrorType__c = 'API_ERROR',
            Integration_Name__c = 'Adobe FA Portal',
            ErrorMessage__c = e.getMessage() + 
                              (String.isNotBlank(agreementId) ? ' | AgreementId: ' + agreementId : ''),
            ErrorStackTrace__c = e.getStackTraceString(),
            Related_Account__c = accountId
        );
        
        errorLogs.add(errorLog);
    }
    
    private static String buildAgreementName(Account a) {
        String base = 'Fee Agreement';
        if (a != null && String.isNotBlank(a.Name)) {
            base = base + ' - ' + a.Name;
        }
        if (base != null && base.length() > 240) {
            base = base.substring(0, 240);
        }
        return base;
    }
}