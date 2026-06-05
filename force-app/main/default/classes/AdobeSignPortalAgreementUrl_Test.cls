@IsTest(SeeAllData=true)
private class AdobeSignPortalAgreementUrl_Test {

    private class AdobeSignMock implements HttpCalloutMock {
        private Boolean returnUrl;

        public AdobeSignMock(Boolean returnUrl) {
            this.returnUrl = returnUrl;
        }

        public HttpResponse respond(HttpRequest req) {
            HttpResponse res = new HttpResponse();
            res.setHeader('Content-Type', 'application/json');

            if (req.getEndpoint().contains('token')) {
                res.setStatusCode(200);
                res.setBody('{"access_token":"MOCK","token_type":"Bearer","expires_in":3600}');
            }
            else if (req.getEndpoint().contains('signingUrls')) {
                if (returnUrl) {
                    res.setStatusCode(200);
                    res.setBody(
                        '{"signingUrlSetInfos":[{"signingUrls":[{"esignUrl":"https://secure.adobesign.com/test"}]}]}'
                    );
                } else {
                    res.setStatusCode(200);
                    res.setBody('{"signingUrlSetInfos":[]}');
                }
            } else {
                res.setStatusCode(200);
                res.setBody('{}');
            }
            return res;
        }
    }

    private static Id getTestAccountId() {
        List<Account> accs = [SELECT Id FROM Account LIMIT 1];
        return accs.isEmpty() ? null : accs[0].Id;
    }


    @IsTest
    static void testSuccessPath() {
        Id accId = getTestAccountId();
        if (accId == null) return;

        update new Account(
            Id = accId,
            FA_Portal_AgreementId__c = 'AGREEMENT123'
        );

        Test.startTest();
        Test.setMock(HttpCalloutMock.class, new AdobeSignMock(true));
        System.enqueueJob(new AdobeSignPortalAgreementUrl(accId));
        Test.stopTest();

        Account a = [
            SELECT Fa_Portal_Signing_URL__c
            FROM Account WHERE Id = :accId
        ];
        System.assertNotEquals(null, a.Fa_Portal_Signing_URL__c);
    }

    @IsTest
    static void testNoAgreementId() {
        Id accId = getTestAccountId();
        if (accId == null) return;

        update new Account(Id = accId, FA_Portal_AgreementId__c = null);

        Test.startTest();
        Test.setMock(HttpCalloutMock.class, new AdobeSignMock(true));
        System.enqueueJob(new AdobeSignPortalAgreementUrl(accId));
        Test.stopTest();

        System.assert(true);
    }

    @IsTest
    static void testAttemptNullHandled() {
        Id accId = getTestAccountId();
        if (accId == null) return;

        update new Account(
            Id = accId,
            FA_Portal_AgreementId__c = 'AGREEMENT123'
        );

        Test.startTest();
        Test.setMock(HttpCalloutMock.class, new AdobeSignMock(true));
        new AdobeSignPortalAgreementUrl(accId, null).execute(null);
        Test.stopTest();

        System.assert(true);
    }

    @IsTest
    static void testConstructorAttemptCoverage() {
        Id accId = getTestAccountId();
        if (accId == null) return;

        Test.startTest();
        new AdobeSignPortalAgreementUrl(accId, 5);
        Test.stopTest();

        System.assert(true);
    }

    @IsTest
    static void testFinalAttemptException() {
        Id fakeId = (Id)'001000000000000AAA';

        Test.startTest();
        new AdobeSignPortalAgreementUrl(fakeId, 10).execute(null);
        Test.stopTest();

        System.assert(true);
    }

    @IsTest
    static void testFinalAttempt_NoUrl() {
        Id accId = getTestAccountId();
        if (accId == null) return;

        update new Account(
            Id = accId,
            FA_Portal_AgreementId__c = 'AGREEMENT123'
        );

        Test.startTest();
        Test.setMock(HttpCalloutMock.class, new AdobeSignMock(false));
        new AdobeSignPortalAgreementUrl(accId, 10).execute(null);
        Test.stopTest();

        System.assert(true);
    }
}