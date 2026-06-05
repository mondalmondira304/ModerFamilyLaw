@IsTest
private class AdobeFinalPdfDownloadJob_Test {
    
    private static final Id TEST_RT_ID = '0124N000000X9Zn';
    
    private class MockHttpResponse implements HttpCalloutMock {
        public HttpResponse respond(HttpRequest req) {
            HttpResponse res = new HttpResponse();
            String endpoint = req.getEndpoint();
            
            if (endpoint.contains('token') || endpoint.contains('oauth')) {
                res.setStatusCode(200);
                res.setHeader('Content-Type', 'application/json');
                res.setBody('{"access_token":"MOCK_TOKEN","token_type":"Bearer"}');
            } else if (endpoint.contains('combinedDocument')) {
                res.setStatusCode(200);
                res.setHeader('Content-Type', 'application/pdf');
                res.setBodyAsBlob(Blob.valueOf('%PDF-1.4 Mock PDF'));
            } else {
                res.setStatusCode(200);
                res.setBody('{}');
            }
            
            return res;
        }
    }
    
    @IsTest
    static void testJob_successfulDownload() {
        Test.setMock(HttpCalloutMock.class, new MockHttpResponse());
        
        Account testAcc = new Account(
            LastName = 'Job Test Account',
            RecordTypeId = TEST_RT_ID,
            FA_Portal_Agreement_Status__c = 'All Signed',
            FA_Portal_AgreementId__c = 'JOB-TEST-AGR-001'
        );
        insert testAcc;
        
        Test.startTest();
        
        System.enqueueJob(
            new AdobeFinalPdfDownloadJob(
                'JOB-TEST-AGR-001',
                'Fee Agreement - Job Test',
                testAcc.Id
            )
        );
        
        Test.stopTest();
        
        Account refreshed = [
            SELECT FA_Portal_Agreement_Status__c
            FROM Account
            WHERE Id = :testAcc.Id
        ];
        
        System.assertEquals(
            'FA_Downloaded',
            refreshed.FA_Portal_Agreement_Status__c,
            'Status should be updated to FA_Downloaded'
        );
    }
    
    @IsTest
    static void testJob_missingParameters() {
        Test.startTest();
        
        System.enqueueJob(
            new AdobeFinalPdfDownloadJob(null, null, null)
        );
        
        Test.stopTest();
        
        List<ErrorLog__c> errors = [
            SELECT Id, ErrorType__c, Method_Name__c
            FROM ErrorLog__c
            WHERE CreatedDate = TODAY
            ORDER BY CreatedDate DESC
            LIMIT 10
        ];
        
        System.assert(!errors.isEmpty(), 'Should have logged error for missing params');
    }
    
    @IsTest
    static void testJob_downloadFailure() {
        // Mock returns 404 error
        Test.setMock(HttpCalloutMock.class, new MockHttpErrorResponse());
        
        Account testAcc = new Account(
            LastName = 'Job Failure Test',
            RecordTypeId = TEST_RT_ID,
            FA_Portal_Agreement_Status__c = 'All Signed',
            FA_Portal_AgreementId__c = 'FAIL-TEST-AGR-001'
        );
        insert testAcc;
        
        Test.startTest();
        
        System.enqueueJob(
            new AdobeFinalPdfDownloadJob(
                'FAIL-TEST-AGR-001',
                'Fee Agreement - Fail Test',
                testAcc.Id
            )
        );
        
        Test.stopTest();
        
        Account refreshed = [
            SELECT FA_Portal_Agreement_Status__c
            FROM Account
            WHERE Id = :testAcc.Id
        ];
        
        System.assertEquals(
            'All Signed',
            refreshed.FA_Portal_Agreement_Status__c,
            'Status should remain All_Signed on failure'
        );
        
        List<ErrorLog__c> errors = [
            SELECT Id, ErrorType__c, Method_Name__c
            FROM ErrorLog__c
            WHERE CreatedDate = TODAY
            AND ErrorType__c = 'API_ERROR'
            ORDER BY CreatedDate DESC
            LIMIT 10
        ];
        
        System.assert(!errors.isEmpty(), 'Should have logged download error');
    }
    
    @IsTest
    static void testJob_resolvesAgreementIdFromAccount() {
        Test.setMock(HttpCalloutMock.class, new MockHttpResponse());
        
        Account testAcc = new Account(
            LastName = 'Job Resolve Test',
            RecordTypeId = TEST_RT_ID,
            FA_Portal_Agreement_Status__c = 'All Signed',
            FA_Portal_AgreementId__c = 'RESOLVE-TEST-AGR-001'
        );
        insert testAcc;
        
        Test.startTest();
        
        System.enqueueJob(
            new AdobeFinalPdfDownloadJob(
                null,  // Agreement ID null
                'Fee Agreement - Resolve Test',
                testAcc.Id
            )
        );
        
        Test.stopTest();
        
        Account refreshed = [
            SELECT FA_Portal_Agreement_Status__c
            FROM Account
            WHERE Id = :testAcc.Id
        ];
        
        System.assertEquals(
            'FA_Downloaded',
            refreshed.FA_Portal_Agreement_Status__c,
            'Should successfully resolve agreementId and process'
        );
    }
    
    private class MockHttpErrorResponse implements HttpCalloutMock {
        public HttpResponse respond(HttpRequest req) {
            HttpResponse res = new HttpResponse();
            
            if (req.getEndpoint().contains('token') || req.getEndpoint().contains('oauth')) {
                res.setStatusCode(200);
                res.setBody('{"access_token":"MOCK_TOKEN"}');
            } else {
                res.setStatusCode(404);
                res.setStatus('Not Found');
                res.setBody('{"error": "Agreement not found"}');
            }
            
            return res;
        }
    }
}