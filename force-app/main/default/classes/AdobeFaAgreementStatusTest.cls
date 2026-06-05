@IsTest(SeeAllData=true)
private class AdobeFaAgreementStatusTest {
    private static HttpRequest lastReq;

    private class Mock implements HttpCalloutMock {
        Integer code;
        String body;

        Mock(Integer code, String body) {
            this.code = code;
            this.body = body;
        }

        public HttpResponse respond(HttpRequest req) {
            String endpoint = req.getEndpoint() == null ? '' : req.getEndpoint().toLowerCase();
            HttpResponse res = new HttpResponse();

            if (endpoint.contains('oauth') || endpoint.contains('token')) {
                res.setStatusCode(200);
                res.setStatus('OK');
                res.setBody('{"access_token":"test-token"}');
                return res;
            }

            lastReq = req;
            res.setStatusCode(code);
            res.setStatus(code == 200 ? 'OK' : 'Bad Request');
            res.setBody(body);
            return res;
        }
    }

    private static AdobeFaAgreementStatus.Request req(String agreementId) {
        AdobeFaAgreementStatus.Request r = new AdobeFaAgreementStatus.Request();
        r.agreementId = agreementId;
        return r;
    }

    @IsTest
    static void testSuccessAndFallback() {
        Test.setMock(HttpCalloutMock.class, new Mock(200, '{"name":"Fee Agreement","state":"OUT_FOR_SIGNATURE"}'));

        Test.startTest();
        List<AdobeFaAgreementStatus.Result> results =
            AdobeFaAgreementStatus.getAgreements(new List<AdobeFaAgreementStatus.Request>{ req('AGR 1') });
        Test.stopTest();

        System.assertEquals(1, results.size());
        System.assertEquals(true, results[0].success);
        System.assertEquals('Fee Agreement', results[0].agreementName);
        System.assertEquals('OUT_FOR_SIGNATURE', results[0].agreementStatus);
        System.assertEquals(200, results[0].statusCode);
        System.assert(lastReq.getEndpoint().contains('/api/rest/v6/agreements/AGR+1'));
        System.assertEquals('GET', lastReq.getMethod());
        System.assert(lastReq.getHeader('Authorization') != null);
        System.assert(lastReq.getHeader('x-api-user') != null && lastReq.getHeader('x-api-user').startsWith('email:'));
    }

    @IsTest
    static void testHttpFailureAndBulk() {
        Test.setMock(HttpCalloutMock.class, new Mock(400, '{"error":"bad"}'));

        Test.startTest();
        List<AdobeFaAgreementStatus.Result> results = AdobeFaAgreementStatus.getAgreements(
            new List<AdobeFaAgreementStatus.Request>{ req('A1'), req('A2') }
        );
        Test.stopTest();

        System.assertEquals(2, results.size());
        System.assertEquals(false, results[0].success);
        System.assertEquals(400, results[0].statusCode);
        System.assert(results[0].errorMessage.contains('HTTP 400'));
        System.assertEquals('{"error":"bad"}', results[0].responseBody);
        System.assertEquals(false, results[1].success);
    }

    @IsTest
    static void testNullEmptyAndValidation() {
        Test.setMock(HttpCalloutMock.class, new Mock(200, '{"name":"x","status":"SIGNED"}'));

        Test.startTest();
        List<AdobeFaAgreementStatus.Result> none1 = AdobeFaAgreementStatus.getAgreements(null);
        List<AdobeFaAgreementStatus.Result> none2 = AdobeFaAgreementStatus.getAgreements(new List<AdobeFaAgreementStatus.Request>());
        AdobeFaAgreementStatus.Result bad1 =
            AdobeFaAgreementStatus.getAgreements(new List<AdobeFaAgreementStatus.Request>{ req(null) })[0];
        AdobeFaAgreementStatus.Result bad2 =
            AdobeFaAgreementStatus.getAgreements(new List<AdobeFaAgreementStatus.Request>{ new AdobeFaAgreementStatus.Request() })[0];
        Test.stopTest();

        System.assertEquals(0, none1.size());
        System.assertEquals(0, none2.size());
        System.assertEquals(false, bad1.success);
        System.assert(bad1.errorMessage.contains('agreementId is required'));
        System.assertEquals(false, bad2.success);
        System.assert(bad2.errorMessage.contains('agreementId is required'));
    }
}