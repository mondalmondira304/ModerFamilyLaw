/**
 * AdobeFinalPdfDownloadJob
 *
 * Downloads PDF from Adobe Sign and saves to Account.
 *
 * Transaction Safety:
 *   - HTTP callouts execute BEFORE any DML
 *   - Avoids "uncommitted work pending" error
 *
 * Triggered by: 
 *   - AdobeSignWebhookHandler (via AdobeFinalAgreementDownloader)
 *   - AdobeFApdfBatch (scheduled batch processing)
 */
public without sharing class AdobeFinalPdfDownloadJob
    implements Queueable, Database.AllowsCallouts {

    private static final String CLASS_NAME = 'AdobeFinalPdfDownloadJob';

    private String agreementId;
    private String agreementName;
    private Id     accountId;

    public class JobParamException extends Exception {}

    /**
     * Constructor
     */
    public AdobeFinalPdfDownloadJob(String agreementId, String agreementName, Id accountId) {
        this.agreementId   = agreementId;
        this.agreementName = agreementName;
        this.accountId     = accountId;
    }

    public void execute(QueueableContext qc) {
        
        if (String.isBlank(this.agreementId) && this.accountId != null) {
            try {
                this.agreementId = [
                    SELECT FA_Portal_AgreementId__c
                    FROM Account
                    WHERE Id = :this.accountId
                    LIMIT 1
                ].FA_Portal_AgreementId__c;
            } catch (Exception ignore) {
            }
        }

        if (String.isBlank(this.agreementId) || this.accountId == null) {
            String msg =
                'Missing required parameters. agreementId=' + this.agreementId +
                ', accountId=' + String.valueOf(this.accountId);
            AdobeFaErrorLogUtil.logError(
                CLASS_NAME,
                'execute',
                new JobParamException(msg),
                this.accountId
            );
            return;
        }

        try {
           
            
            String token = AdobeSignTokenUtil.getAccessToken();
            if (String.isBlank(token)) {
                throw new AdobeFinalAgreementDownloader.DownloadException(
                    'Access token retrieval failed'
                );
            }

            Blob finalPdf =
                AdobeFinalAgreementDownloader.downloadSignedPdf(agreementId, token);
            if (finalPdf == null || finalPdf.size() == 0) {
                throw new AdobeFinalAgreementDownloader.DownloadException(
                    'PDF download returned empty blob'
                );
            }

            
            
            AdobeAgreementFileSaver.saveFinalPdf(
                finalPdf,
                accountId,
                agreementId,
                agreementName
            );
            
            update new Account(
                Id = accountId,
                FA_Portal_Agreement_Status__c = 'FA_Downloaded'
            );

        } catch (Exception e) {
            AdobeFaErrorLogUtil.logError(
                CLASS_NAME,
                'execute',
                e,
                accountId,
                null,
                'PDF download failed. AgreementId: ' + agreementId,
                AdobeFaErrorLogUtil.ErrorType.API_ERROR
            );
        }
    }
}