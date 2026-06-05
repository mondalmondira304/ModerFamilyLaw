public without sharing class AdobeAgreementFileSaver {
    private static final String CLASS_NAME = 'AdobeAgreementFileSaver';
    
    public class FileSaveException extends Exception {}
    
    public static void saveFinalPdf(
        Blob   pdfBlob,
        Id     accountId,
        String agreementId,
        String agreementName
    ) {
        if (accountId == null) {
            FileSaveException ex = new FileSaveException('AccountId is required to link file.');
            AdobeFaErrorLogUtil.logError(CLASS_NAME, 'saveFinalPdf', ex, null);
            throw ex;
        }
        if (pdfBlob == null || pdfBlob.size() == 0) {
            FileSaveException ex = new FileSaveException('PDF Blob is null or empty; nothing to save.');
            AdobeFaErrorLogUtil.logError(CLASS_NAME, 'saveFinalPdf', ex, accountId);
            throw ex;
        }
        
        String baseTitle;
        if (String.isNotBlank(agreementName)) {
            baseTitle = agreementName;
        } else {
            baseTitle = 'Fee Agreement';
        }
        
        String fileName = baseTitle;
        if (!fileName.toLowerCase().endsWith('.pdf')) {
            fileName += '.pdf';
        }
        
        try {
            ContentVersion cv = new ContentVersion();
            cv.Title                  = baseTitle;
            cv.PathOnClient           = fileName;
            cv.VersionData            = pdfBlob;
            cv.FirstPublishLocationId = accountId; 
            insert cv;
            
            ContentVersion insertedCv = [
                SELECT Id, ContentDocumentId
                FROM ContentVersion
                WHERE Id = :cv.Id
                LIMIT 1
            ];
            
            if (insertedCv.ContentDocumentId == null) {
                throw new FileSaveException('ContentDocumentId is null after insert');
            }
            
            // Stage the file link for Matter (replaces the beta ContentVersion flow trigger)
            AdobeFAMatterFileLinkHandler.Request linkReq = new AdobeFAMatterFileLinkHandler.Request();
            linkReq.accountId         = accountId;
            linkReq.contentDocumentId = insertedCv.ContentDocumentId;
            linkReq.fileTitle         = baseTitle;
            AdobeFAMatterFileLinkHandler.link(
                new List<AdobeFAMatterFileLinkHandler.Request>{ linkReq }
            );
            
        } catch (Exception e) {
            AdobeFaErrorLogUtil.logError(
                CLASS_NAME, 
                'saveFinalPdf', 
                e, 
                accountId,
                null,
                'AgreementId: ' + agreementId + ', AgreementName: ' + agreementName,
                AdobeFaErrorLogUtil.ErrorType.SYSTEM_ERROR
            );
            throw new FileSaveException('Failed to save final PDF: ' + e.getMessage());
        }
    }
}