/**
 * AdobeFinalAgreementDownloader_Test
 * 
 * Test coverage for AdobeFinalAgreementDownloader
 */
@IsTest
private class AdobeFinalAgreementDownloader_Test {
    
    private class MockHttpResponse implements HttpCalloutMock {
        public HttpResponse respond(HttpRequest req) {
            HttpResponse res = new HttpResponse();
            res.setStatusCode(200);
            res.setHeader('Content-Type', 'application/pdf');
            res.setBodyAsBlob(Blob.valueOf('%PDF-1.4 Mock PDF Content'));
            return res;
        }
    }
    
    private class MockHttpErrorResponse implements HttpCalloutMock {
        public HttpResponse respond(HttpRequest req) {
            HttpResponse res = new HttpResponse();
            res.setStatusCode(404);
            res.setStatus('Not Found');
            res.setBody('{"error": "Agreement not found"}');
            return res;
        }
    }
    
    @IsTest
    static void testDownloadSignedPdf_success() {
        Test.setMock(HttpCalloutMock.class, new MockHttpResponse());
        
        Test.startTest();
        Blob result = AdobeFinalAgreementDownloader.downloadSignedPdf(
            'TEST-AGREEMENT-123',
            'mock-access-token'
        );
        Test.stopTest();
        
        System.assertNotEquals(null, result, 'PDF blob should not be null');
        System.assert(result.size() > 0, 'PDF blob should have content');
    }
    
    @IsTest
    static void testDownloadSignedPdf_missingAgreementId() {
        Test.startTest();
        
        try {
            AdobeFinalAgreementDownloader.downloadSignedPdf(null, 'mock-token');
            System.assert(false, 'Should have thrown DownloadException');
        } catch (AdobeFinalAgreementDownloader.DownloadException e) {
            System.assert(
                e.getMessage().contains('Agreement Id is required'),
                'Error message should mention Agreement Id'
            );
        }
        
        Test.stopTest();
    }
    
    @IsTest
    static void testDownloadSignedPdf_missingAccessToken() {
        Test.startTest();
        
        try {
            AdobeFinalAgreementDownloader.downloadSignedPdf('AGR-123', null);
            System.assert(false, 'Should have thrown DownloadException');
        } catch (AdobeFinalAgreementDownloader.DownloadException e) {
            System.assert(
                e.getMessage().contains('Access token is required'),
                'Error message should mention access token'
            );
        }
        
        Test.stopTest();
    }
    
    @IsTest
    static void testDownloadSignedPdf_httpError() {
        Test.setMock(HttpCalloutMock.class, new MockHttpErrorResponse());
        
        Test.startTest();
        
        try {
            AdobeFinalAgreementDownloader.downloadSignedPdf(
                'INVALID-AGREEMENT',
                'mock-token'
            );
            System.assert(false, 'Should have thrown DownloadException');
        } catch (AdobeFinalAgreementDownloader.DownloadException e) {
            System.assert(
                e.getMessage().contains('Failed to download'),
                'Error should mention download failure'
            );
        }
        
        Test.stopTest();
    }
}