public without sharing class AdobeSignPortalAgreementUrl
    implements Queueable, Database.AllowsCallouts {

    private static final String CLASS_NAME = 'AdobeSignPortalAgreementUrl';

    private Id accountId;
    private Integer attempt;

    // First attempt constructor
    public AdobeSignPortalAgreementUrl(Id accId) {
        this.accountId = accId;
        this.attempt   = 1;
    }

    // Internal constructor for retries
    public AdobeSignPortalAgreementUrl(Id accId, Integer attemptNum) {
        this.accountId = accId;
        this.attempt   = attemptNum;
    }

    public void execute(QueueableContext qc) {
        if (attempt == null) attempt = 1;
        Integer maxAttempts = 10;
        Boolean isFinalAttempt = (attempt >= maxAttempts);

        try {
            // 1) Load Account with saved agreementId
            Account acc = [
                SELECT Id, FA_Portal_AgreementId__c
                FROM Account
                WHERE Id = :accountId
                LIMIT 1
            ];

            String agreementId = acc.FA_Portal_AgreementId__c;

            if (String.isBlank(agreementId)) {
                // Log error - no agreement ID on account 
                AdobeFaErrorLogUtil.logError(
                    CLASS_NAME,
                    'execute',
                    new AdobeSignPortalAgreement.AdobeConfigException('No agreementId found on Account'),
                    accountId,
                    null,
                    'Attempt: ' + attempt + '/' + maxAttempts,
                    AdobeFaErrorLogUtil.ErrorType.DATA_ERROR
                );

                AdobeFaErrorLogUtil.createErrorTask(
                    accountId,
                    'Adobe Sign URL Fetch Failed',
                    'No agreement ID found on Account record. Cannot fetch signing URL.',
                    null
                );
                return;
            }

            // 2) Single attempt to get signing URL (NO API error logging during retries)
            String signingUrl = AdobeSignPortalAgreement.getSigningUrl(agreementId, false);

            if (String.isBlank(signingUrl)) {
                // Not ready yet
                if (!isFinalAttempt) {
                    System.enqueueJob(
                        new AdobeSignPortalAgreementUrl(accountId, attempt + 1)
                    );
                } else {
                    // Max attempts reached - log error ONLY here
                    AdobeFaErrorLogUtil.logError(
                        CLASS_NAME,
                        'execute',
                        new AdobeSignPortalAgreement.AdobeConfigException(
                            'Signing URL not ready after ' + maxAttempts + ' attempts'
                        ),
                        accountId,
                        null,
                        'Agreement ID: ' + agreementId + ', Attempts: ' + maxAttempts,
                        AdobeFaErrorLogUtil.ErrorType.API_ERROR
                    );

                    AdobeFaErrorLogUtil.createErrorTask(
                        accountId,
                        'Adobe Sign Signing URL Not Available',
                        'The signing URL could not be retrieved after ' + maxAttempts +
                        ' attempts. Agreement ID: ' + agreementId +
                        '. You may need to manually generate the signing URL from Adobe Sign.',
                        null
                    );
                }
                return;
            }

            // 3) Save URL on Account - success!
            update new Account(
                Id = accountId,
                Fa_Portal_Signing_URL__c = signingUrl
            );

        } catch (Exception e) {
            // Only log/create task on FINAL attempt
            if (isFinalAttempt) {
                AdobeFaErrorLogUtil.logError(
                    CLASS_NAME,
                    'execute',
                    e,
                    accountId,
                    null,
                    'Attempt: ' + attempt + '/' + maxAttempts,
                    AdobeFaErrorLogUtil.ErrorType.SYSTEM_ERROR
                );

                AdobeFaErrorLogUtil.createErrorTask(
                    accountId,
                    'Adobe Sign URL Fetch Error',
                    'Unexpected error retrieving signing URL: ' + e.getMessage() +
                    '. Attempt ' + attempt + ' of ' + maxAttempts,
                    null
                );
            }

            if (!isFinalAttempt) {
                System.enqueueJob(
                    new AdobeSignPortalAgreementUrl(accountId, attempt + 1)
                );
            }
        }
    }
}