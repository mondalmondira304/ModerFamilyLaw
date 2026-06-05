/**
 * AdobeFinalAgreementDownloader
 * 
 * Handles downloading the final signed PDF from Adobe Sign API.
 * 
 * Called by: AdobeFApdfBatch
 */
public without sharing class AdobeFinalAgreementDownloader {
    
    private static final String BASE_API_URL = 'https://api.na3.adobesign.com/api/rest/v6';
    private static final String CLASS_NAME   = 'AdobeFinalAgreementDownloader';

    private static final String X_API_USER_VALUE = 'email:mfl.adobe@modernfamilylaw.com';
    
    public class DownloadException extends Exception {}
    
    /**
     * Download the final combined (signed) PDF from Adobe Sign.
     * 
     * GET /api/rest/v6/agreements/{agreementId}/combinedDocument
     * 
     * @param agreementId  Adobe Sign agreement ID
     * @param accessToken  Valid OAuth bearer token
     * @return Blob containing the signed PDF bytes
     * @throws DownloadException on any failure
     */
    public static Blob downloadSignedPdf(String agreementId, String accessToken) {
        
        if (String.isBlank(agreementId)) {
            throw new DownloadException('Agreement Id is required');
        }
        if (String.isBlank(accessToken)) {
            throw new DownloadException('Access token is required');
        }
        
        String encodedId = EncodingUtil.urlEncode(agreementId, 'UTF-8');
        String endpoint  = BASE_API_URL + '/agreements/' + encodedId + '/combinedDocument';
        
        HttpRequest req = new HttpRequest();
        req.setMethod('GET');
        req.setEndpoint(endpoint);
        req.setTimeout(60000);
        req.setHeader('Authorization', 'Bearer ' + accessToken);

        req.setHeader('x-api-user', X_API_USER_VALUE);

        req.setHeader('Accept', 'application/pdf');
        
        Http http = new Http();
        HttpResponse res;
        
        try {
            res = http.send(req);
        } catch (System.CalloutException ce) {
            throw new DownloadException('Callout to Adobe failed: ' + ce.getMessage());
        }
        
        Integer statusCode = res.getStatusCode();
        String  status     = res.getStatus();
        
        if (statusCode >= 200 && statusCode < 300) {
            Blob pdfBlob = res.getBodyAsBlob();
            return pdfBlob;
        } else {
            String bodySnippet = res.getBody();
            if (bodySnippet != null && bodySnippet.length() > 1000) {
                bodySnippet = bodySnippet.substring(0, 1000) + '... (truncated)';
            }
            
            throw new DownloadException(
                'Failed to download signed PDF. HTTP ' + statusCode + ' ' + status +
                ' | AgreementId: ' + agreementId +
                ' | Response: ' + bodySnippet
            );
        }
    }
}