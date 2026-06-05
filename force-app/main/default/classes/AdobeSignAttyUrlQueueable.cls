public without sharing class AdobeSignAttyUrlQueueable
    implements Queueable, Database.AllowsCallouts {
    private static final String CLASS_NAME = 'AdobeSignAttyUrlQueueable';
    private static Boolean isExecuting = false;
    
    private Id accountId;
    private String agreementId;
    private Integer attempt;
    
    public AdobeSignAttyUrlQueueable(Id accId, String agreeId) {
        this.accountId = accId;
        this.agreementId = agreeId;
        this.attempt = 1;
    }
    
    public AdobeSignAttyUrlQueueable(Id accId, String agreeId, Integer attemptNum) {
        this.accountId = accId;
        this.agreementId = agreeId;
        this.attempt = attemptNum;
    }
    
    public void execute(QueueableContext qc) {
        // Prevent re-entry
        if (isExecuting) {
            return;
        }
        isExecuting = true;
        
        try {
            executeInternal();
        } finally {
            isExecuting = false;
        }
    }
    
    private void executeInternal() {
        if (attempt == null) attempt = 1;
        Integer maxAttempts = 10;
        
        Account acc = [
            SELECT Id,
                   Name,
                   FA_Portal_Agreement_Status__c,
                   FA_Portal_Atty_Signing_URL__c
            FROM Account
            WHERE Id = :accountId
            LIMIT 1
        ];
        
        if (String.isBlank(agreementId)) {
            AdobeFaErrorLogUtil.logError(
                CLASS_NAME,
                'execute',
                new AdobeSignException('Missing agreementId'),
                accountId
            );
            return;
        }
        
        String signingUrl = AdobeSignPortalAgreement.getSigningUrl(agreementId);
        
        if (String.isBlank(signingUrl)) {
            if (attempt < maxAttempts) {
                System.enqueueJob(
                    new AdobeSignAttyUrlQueueable(accountId, agreementId, attempt + 1)
                );
            } else {
                AdobeFaErrorLogUtil.logError(
                    CLASS_NAME,
                    'execute',
                    new AdobeSignException('URL not ready after ' + maxAttempts + ' attempts'),
                    accountId,
                    null,
                    'AgreementId: ' + agreementId,
                    AdobeFaErrorLogUtil.ErrorType.API_ERROR
                );
            }
            return;
        }
        
        update new Account(
            Id = accountId,
            FA_Portal_Atty_Signing_URL__c = signingUrl
        );
        
        AdobeSignAttySigningUrl.sendAttorneySigningNotification(accountId, signingUrl);
    }
    
    public class AdobeSignException extends Exception {}
}