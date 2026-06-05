@IsTest
private class AdobeFaCancelTest {
    private static HttpRequest lastReq;

    private class Mock implements HttpCalloutMock {
        Integer code;
        String body;

        Mock(Integer c, String b) {
            code = c;
            body = b;
        }

        public HttpResponse respond(HttpRequest req) {
            lastReq = req;
            HttpResponse res = new HttpResponse();
            res.setStatusCode(code);
            res.setStatus(code == 200 ? 'OK' : 'Bad Request');
            res.setBody(body);
            return res;
        }
    }

    private static Adobe_Integration_Config__mdt cfg(String baseUrl, String apiUser) {
        Adobe_Integration_Config__mdt c = new Adobe_Integration_Config__mdt();
        c.Api_Base_Url__c = baseUrl;
        c.Adobe_API_User__c = apiUser;
        c.Is_Active__c = true;
        return c;
    }

    private static AdobeFaCancel.Request req(String id, String comment, Boolean notify) {
        AdobeFaCancel.Request r = new AdobeFaCancel.Request();
        r.agreementId = id;
        r.comment = comment;
        r.notifyOthers = notify;
        return r;
    }

    @IsTest
    static void testSuccessAndBulk() {
        AdobeFaCancel.testConfigOverride = cfg('https://api.adobe.com///', ' user@test.com ');
        AdobeFaCancel.testAccessTokenOverride = 'tok';
        Test.setMock(HttpCalloutMock.class, new Mock(200, '{"ok":true}'));

        Test.startTest();
        List<AdobeFaCancel.Result> results = AdobeFaCancel.cancelFromFlow(new List<AdobeFaCancel.Request>{
            req('AGR-1', 'Cancel now', false),
            req('AGR 2', null, null)
        });
        Test.stopTest();

        System.assertEquals(2, results.size());
        System.assertEquals(true, results[0].success);
        System.assertEquals(200, results[0].statusCode);
        System.assertEquals(true, results[1].success);
        System.assertEquals('https://api.adobe.com/api/rest/v6/agreements/AGR+2/state', lastReq.getEndpoint());
        System.assertEquals('PUT', lastReq.getMethod());
        System.assertEquals('Bearer tok', lastReq.getHeader('Authorization'));
        System.assertEquals('email:user@test.com', lastReq.getHeader('x-api-user'));

        Map<String, Object> payload = (Map<String, Object>)JSON.deserializeUntyped(lastReq.getBody());
        System.assertEquals('CANCELLED', payload.get('state'));
        Map<String, Object> info = (Map<String, Object>)payload.get('agreementCancellationInfo');
        System.assertEquals(true, info.get('notifyOthers'));
        System.assertEquals(null, info.get('comment'));
    }

    @IsTest
    static void testHttpFailure() {
        AdobeFaCancel.testConfigOverride = cfg('https://api.adobe.com', 'user@test.com');
        AdobeFaCancel.testAccessTokenOverride = 'tok';
        Test.setMock(HttpCalloutMock.class, new Mock(400, '{"error":"bad"}'));

        Test.startTest();
        AdobeFaCancel.Result r = AdobeFaCancel.cancelFromFlow(new List<AdobeFaCancel.Request>{
            req('AGR-3', 'x', true)
        })[0];
        Test.stopTest();

        System.assertEquals(false, r.success);
        System.assertEquals(400, r.statusCode);
        System.assert(r.errorMessage.contains('HTTP 400'));
        System.assertEquals('{"error":"bad"}', r.responseBody);
    }

    @IsTest
    static void testValidationAndEmptyCases() {
        AdobeFaCancel.testConfigOverride = cfg('https://api.adobe.com', 'user@test.com');
        AdobeFaCancel.testAccessTokenOverride = 'tok';

        Test.startTest();
        List<AdobeFaCancel.Result> empty1 = AdobeFaCancel.cancelFromFlow(null);
        List<AdobeFaCancel.Result> empty2 = AdobeFaCancel.cancelFromFlow(new List<AdobeFaCancel.Request>());
        AdobeFaCancel.Result missingId = AdobeFaCancel.cancelFromFlow(new List<AdobeFaCancel.Request>{ req(null, null, null) })[0];

        AdobeFaCancel.testConfigOverride = cfg('', 'user@test.com');
        AdobeFaCancel.Result badBase = AdobeFaCancel.cancelFromFlow(new List<AdobeFaCancel.Request>{ req('AGR-4', null, null) })[0];

        AdobeFaCancel.testConfigOverride = cfg('https://api.adobe.com', '');
        AdobeFaCancel.Result badUser = AdobeFaCancel.cancelFromFlow(new List<AdobeFaCancel.Request>{ req('AGR-5', null, null) })[0];

        AdobeFaCancel.testConfigOverride = cfg('https://api.adobe.com', 'user@test.com');
        AdobeFaCancel.testAccessTokenOverride = '';
        AdobeFaCancel.Result badToken = AdobeFaCancel.cancelFromFlow(new List<AdobeFaCancel.Request>{ req('AGR-6', null, null) })[0];
        Test.stopTest();

        System.assertEquals(0, empty1.size());
        System.assertEquals(0, empty2.size());
        System.assertEquals(false, missingId.success);
        System.assert(missingId.errorMessage.contains('agreementId is required'));
        System.assertEquals(false, badBase.success);
        System.assert(badBase.errorMessage.contains('Api_Base_Url__c is blank'));
        System.assertEquals(false, badUser.success);
        System.assert(badUser.errorMessage.contains('Adobe_API_User__c is blank'));
        System.assertEquals(false, badToken.success);
        System.assert(badToken.errorMessage.contains('access token is blank'));
    }
}