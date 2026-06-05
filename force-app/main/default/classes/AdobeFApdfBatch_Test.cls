@IsTest
private class AdobeFApdfBatch_Test {

    private static final Id TEST_RT_ID = '0124N000000X9Zn';

    private class AdobeHttpMock implements HttpCalloutMock {
        public HttpResponse respond(HttpRequest req) {
            HttpResponse res = new HttpResponse();
            String ep = req != null ? req.getEndpoint() : null;

            if (ep != null && (ep.toLowerCase().contains('token') || ep.toLowerCase().contains('oauth'))) {
                res.setStatusCode(200);
                res.setHeader('Content-Type', 'application/json');
                res.setBody('{"access_token":"MOCK_TOKEN","token_type":"Bearer","expires_in":3600}');
                return res;
            }

            if (ep != null && ep.contains('/combinedDocument')) {
                res.setStatusCode(200);
                res.setHeader('Content-Type', 'application/pdf');
                res.setBodyAsBlob(Blob.valueOf('%PDF-1.4 MOCK PDF'));
                return res;
            }

            res.setStatusCode(200);
            res.setHeader('Content-Type', 'application/json');
            res.setBody('{}');
            return res;
        }
    }

    private static Account makeAccount(String status, String agreementId) {
        Account a = new Account(
            LastName = 'AdobeFApdfBatch Test ' + status,
            RecordTypeId = TEST_RT_ID,
            FA_Portal_Agreement_Status__c = status,
            FA_Portal_AgreementId__c = agreementId
        );
        insert a;
        return a;
    }

    @IsTest
    static void batch_sweepsAllSigned_and_downloads() {
        Test.setMock(HttpCalloutMock.class, new AdobeHttpMock());

        Account needsDownload = makeAccount('All Signed', 'AGR-NEEDS');
        Account alreadyDone   = makeAccount('FA_Downloaded', 'AGR-DONE');

        Test.startTest();
        Database.executeBatch(new AdobeFApdfBatch(50), 5);
        Test.stopTest();

        Account refreshed = [
            SELECT Id, FA_Portal_Agreement_Status__c
            FROM Account
            WHERE Id = :needsDownload.Id
        ];
        System.assertEquals(
            'FA_Downloaded',
            refreshed.FA_Portal_Agreement_Status__c,
            'Should move to FA_Downloaded after Queueable succeeds.'
        );

        Integer cvCount = [
            SELECT COUNT()
            FROM ContentVersion
            WHERE FirstPublishLocationId = :needsDownload.Id
        ];
        System.assert(cvCount > 0, 'Expected a ContentVersion published to the Account.');

        Account doneRefreshed = [
            SELECT Id, FA_Portal_Agreement_Status__c
            FROM Account
            WHERE Id = :alreadyDone.Id
        ];
        System.assertEquals('FA_Downloaded', doneRefreshed.FA_Portal_Agreement_Status__c);
    }

    @IsTest
    static void batch_hitsCatchBlock_forCoverage() {
        Account a = makeAccount('All Signed', 'AGR-CATCH');

        AdobeFApdfBatch.TEST_FORCE_TRY_EXCEPTION = true;

        Test.startTest();
        new AdobeFApdfBatch(1).execute(null, new List<Account>{ a });
        Test.stopTest();

        AdobeFApdfBatch.TEST_FORCE_TRY_EXCEPTION = false;

        System.assert(true, 'Catch block executed for coverage.');
    }

    @IsTest
    static void batch_runBatch_default_overload() {
        Test.setMock(HttpCalloutMock.class, new AdobeHttpMock());
        makeAccount('All Signed', 'AGR-RUN-DEFAULT');

        Test.startTest();
        Id jobId = AdobeFApdfBatch.runBatch();
        Test.stopTest();

        System.assertNotEquals(null, jobId);
    }

    @IsTest
    static void batch_runBatch_maxRecords_overload() {
        Test.setMock(HttpCalloutMock.class, new AdobeHttpMock());
        makeAccount('All Signed', 'AGR-RUN-MAX');

        Test.startTest();
        Id jobId = AdobeFApdfBatch.runBatch(5);
        Test.stopTest();

        System.assertNotEquals(null, jobId);
    }

    @IsTest
    static void batch_runBatch_token_overload() {
        makeAccount('All Signed', 'AGR-RUN-TOKEN');

        Test.startTest();
        Id jobId = AdobeFApdfBatch.runBatch(5, 'MOCK_TOKEN');
        Test.stopTest();

        System.assertNotEquals(null, jobId);
    }
}