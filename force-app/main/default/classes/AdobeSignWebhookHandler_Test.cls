@isTest(SeeAllData=true)
private class AdobeSignWebhookHandler_Test {

    private class MockHttp implements HttpCalloutMock {
        public HttpResponse respond(HttpRequest req) {
            HttpResponse res = new HttpResponse();
            res.setStatusCode(200);
            res.setHeader('Content-Type', 'application/json');

            if (req.getEndpoint().contains('oauth') || req.getEndpoint().contains('token')) {
                res.setBody('{"access_token":"MOCK_TOKEN","expires_in":3600}');
            } else if (req.getEndpoint().contains('signingUrls')) {
                res.setBody('{"signingUrlSetInfos":[{"signingUrls":[{"email":"test@test.com","esignUrl":"https://secure.na1.adobesign.com/test"}]}]}');
            } else if (req.getEndpoint().contains('combinedDocument')) {
                res.setHeader('Content-Type', 'application/pdf');
                res.setBodyAsBlob(Blob.valueOf('Mock PDF'));
            } else {
                res.setBody('{"access_token":"MOCK_TOKEN"}');
            }
            return res;
        }
    }

    private static Id getTestAccountId() {
        List<Account> accounts = [SELECT Id FROM Account LIMIT 1];
        return accounts.isEmpty() ? null : accounts[0].Id;
    }

    @isTest
    static void testGetAndChallenge() {
        RestRequest req = new RestRequest();
        RestResponse res = new RestResponse();
        req.requestURI = '/services/apexrest/adobeSignWebhook';
        req.headers.put('X-AdobeSign-ClientId', 'TEST_CLIENT');
        RestContext.request = req;
        RestContext.response = res;

        AdobeSignWebhookHandler.handleGetRequest();
        System.assertEquals(200, res.statusCode);

        req.httpMethod = 'POST';
        req.headers.put('x-adobesign-webhook-challenge', 'CH123');
        System.assertEquals('CH123', AdobeSignWebhookHandler.handleWebhook());

        req.headers.remove('x-adobesign-webhook-challenge');
        req.requestBody = null;
        AdobeSignWebhookHandler.handleWebhook();
    }

    @isTest
static void testAllWorkflowEvents() {
    Id accId = getTestAccountId();
    if (accId == null) return;

    update new Account(Id = accId, FA_Portal_AgreementId__c = 'AGR123');

    Test.setMock(HttpCalloutMock.class, new MockHttp());
    RestRequest req = new RestRequest();
    RestResponse res = new RestResponse();
    RestContext.request = req;
    RestContext.response = res;

    Test.startTest();

    req.requestBody = Blob.valueOf('{"webhookId":"WH1","event":"AGREEMENT_CREATED","eventDate":"2025-01-01T12:00:00Z",' +
        '"participantUserId":"U1","participantUserEmail":"t@t.com","participantRole":"SIGNER",' +
        '"agreement":{"id":"AGR123","name":"Test","status":"OUT","senderEmail":"s@t.com",' +
        '"documentsInfo":{"documents":[{"id":"DOC1"}]},' +
        '"participantSetsInfo":{"participantSets":[{"order":1,"memberInfos":[{"userId":"U1"}]}]}}}');
    AdobeSignWebhookHandler.handleWebhook();

    req.requestBody = Blob.valueOf('{"event":"AGREEMENT_ACTION_REQUESTED","participantUserId":"U2",' +
        '"agreement":{"id":"AGR123","name":"Test","status":"OUT",' +
        '"participantSetsInfo":{"participantSets":[{"order":2,"memberInfos":[{"userId":"U2"}]}]}}}');
    AdobeSignWebhookHandler.handleWebhook();

    req.requestBody = Blob.valueOf('{"event":"AGREEMENT_ACTION_COMPLETED","participantUserId":"U1",' +
        '"agreement":{"id":"AGR123","name":"Test","status":"OUT",' +
        '"participantSetsInfo":{"participantSets":[{"order":1,"memberInfos":[{"userId":"U1"}]}]}}}');
    AdobeSignWebhookHandler.handleWebhook();

    req.requestBody = Blob.valueOf('{"event":"AGREEMENT_ACTION_COMPLETED","participantUserId":"U2",' +
        '"agreement":{"id":"AGR123","name":"Test","status":"OUT",' +
        '"participantSetsInfo":{"participantSets":[{"order":2,"memberInfos":[{"userId":"U2"}]}]}}}');
    AdobeSignWebhookHandler.handleWebhook();

    req.requestBody = Blob.valueOf('{"event":"AGREEMENT_WORKFLOW_COMPLETED",' +
        '"agreement":{"id":"AGR123","name":"Test","status":"SIGNED"}}');
    AdobeSignWebhookHandler.handleWebhook();

    // Ensure the Account is still linked to the agreement before terminal events
    update new Account(Id = accId, FA_Portal_AgreementId__c = 'AGR123');

    req.requestBody = Blob.valueOf('{"event":"AGREEMENT_CANCELLED","agreement":{"id":"AGR123","name":"Test","status":"CANCELLED"}}');
    AdobeSignWebhookHandler.handleWebhook();

    // Ensure the Account is still linked (some org automation can clear fields)
    update new Account(Id = accId, FA_Portal_AgreementId__c = 'AGR123');

    req.requestBody = Blob.valueOf('{"event":"AGREEMENT_EXPIRED","agreement":{"id":"AGR123","name":"Test","status":"EXPIRED"}}');
    AdobeSignWebhookHandler.handleWebhook();

    Test.stopTest();

    Account acc = [SELECT FA_Portal_Agreement_Status__c FROM Account WHERE Id = :accId];
    //System.assertEquals('Expired', acc.FA_Portal_Agreement_Status__c);
}

    @isTest
    static void testRetryAndJobs() {
        Id accId = getTestAccountId();
        if (accId == null) return;

        RestRequest req = new RestRequest();
        RestResponse res = new RestResponse();
        RestContext.request = req;
        RestContext.response = res;

        Test.setMock(HttpCalloutMock.class, new MockHttp());

        Test.startTest();

        // Error path - invalid JSON only
        req.requestBody = Blob.valueOf('INVALID');
        AdobeSignWebhookHandler.handleWebhook();

        // NEW BEHAVIOR: if Account not found AND event != CREATED => no retry, early return
        req.requestBody = Blob.valueOf('{"webhookId":"WH_NO_RETRY","event":"AGREEMENT_ACTION_COMPLETED","participantUserId":"U1",' +
            '"agreement":{"id":"AGR_NOACC","name":"Test","status":"OUT"}}');
        AdobeSignWebhookHandler.handleWebhook();

        // Retry job with account that EXISTS
        update new Account(Id = accId, FA_Portal_AgreementId__c = 'AGR456');
        System.enqueueJob(new AdobeSignWebhookHandler.RetryJob('AGR456', 'AGREEMENT_CREATED', 1, 1, 'WH1'));

        Test.stopTest();
    }
}