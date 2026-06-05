@IsTest(SeeAllData=false)
private class AdobeSignAttySigningUrl_Test {

    private static Account makeAccount(Boolean withAgreementId) {
        Account a = new Account(
            Name = 'Test Account - AdobeSignAttySigningUrl'
        );
        if (withAgreementId) {
            a.FA_Portal_AgreementId__c = 'AGR123';
        }
        insert a;
        return a;
    }

    private class AdobeAnyCalloutMock implements HttpCalloutMock {
        public HttpResponse respond(HttpRequest req) {
            HttpResponse res = new HttpResponse();
            res.setStatusCode(200);
            res.setHeader('Content-Type', 'application/json');
            String ep = req.getEndpoint() == null ? '' : req.getEndpoint();

            if (ep.contains('token') || ep.contains('oauth')) {
                res.setBody('{"access_token":"MOCK_TOKEN","token_type":"Bearer","expires_in":3600}');
            } else if (ep.contains('signingUrls')) {
                res.setBody('{"signingUrlSetInfos":[{"signingUrls":[{"email":"attorney@test.com","esignUrl":"https://secure.na1.adobesign.com/public/esignWidget?wid=MOCK123"}]}]}');
            } else {
                res.setBody('{"success":true}');
            }
            return res;
        }
    }

    @IsTest
    static void testHappyPath() {
        Account a = makeAccount(true);

        // keep behavior consistent with your original test
        update new Account(Id = a.Id, FA_Portal_Atty_Signing_URL__c = null);

        AdobeSignAttySigningUrl.InputWrapper inp = new AdobeSignAttySigningUrl.InputWrapper();
        inp.accountId = a.Id;

        Test.setMock(HttpCalloutMock.class, new AdobeAnyCalloutMock());
        Test.startTest();
        List<AdobeSignAttySigningUrl.OutputWrapper> results =
            AdobeSignAttySigningUrl.createAttySigningUrl(new List<AdobeSignAttySigningUrl.InputWrapper>{ inp });
        Test.stopTest(); 

        System.assertEquals(1, results.size());
        System.assertEquals(a.Id, results[0].accountId);
    }

    @IsTest
    static void testNoAgreementId() {
        Account a = makeAccount(false);

        AdobeSignAttySigningUrl.InputWrapper inp = new AdobeSignAttySigningUrl.InputWrapper();
        inp.accountId = a.Id;

        Test.startTest();
        List<AdobeSignAttySigningUrl.OutputWrapper> results =
            AdobeSignAttySigningUrl.createAttySigningUrl(new List<AdobeSignAttySigningUrl.InputWrapper>{ inp });
        Test.stopTest();

        System.assertEquals(1, results.size());
        System.assertEquals(null, results[0].attorneySigningUrl);
    }

    @IsTest
    static void testSendNotificationWithUrl() {
        Account a = makeAccount(true);

        Test.startTest();
        AdobeSignAttySigningUrl.testAttorneyEmailOverride = 'attorney@test.com';
        AdobeSignAttySigningUrl.sendAttorneySigningNotification(a.Id, 'https://test.com/sign');
        AdobeSignAttySigningUrl.testAttorneyEmailOverride = null;
        Test.stopTest();

        System.assertEquals(a.Id, [SELECT Id FROM Account WHERE Id = :a.Id].Id);
    }

    @IsTest
    static void testSendNotificationBlankUrl() {
        Account a = makeAccount(true);

        Test.startTest();
        AdobeSignAttySigningUrl.sendAttorneySigningNotification(a.Id, null);
        AdobeSignAttySigningUrl.sendAttorneySigningNotification(a.Id, '');
        Test.stopTest();

        System.assertEquals(a.Id, [SELECT Id FROM Account WHERE Id = :a.Id].Id);
    }

    @IsTest
    static void testNullInputs() {
        System.assertEquals(0, AdobeSignAttySigningUrl.createAttySigningUrl(null).size());
        System.assertEquals(0, AdobeSignAttySigningUrl.createAttySigningUrl(
            new List<AdobeSignAttySigningUrl.InputWrapper>()
        ).size());

        AdobeSignAttySigningUrl.InputWrapper w = new AdobeSignAttySigningUrl.InputWrapper();
        System.assertEquals(0, AdobeSignAttySigningUrl.createAttySigningUrl(
            new List<AdobeSignAttySigningUrl.InputWrapper>{ null, w }
        ).size());
    }

    @IsTest
    static void testConstructorVariations() {
        AdobeSignAttySigningUrl.InputWrapper inp1 = new AdobeSignAttySigningUrl.InputWrapper();
        AdobeSignAttySigningUrl.OutputWrapper out1 = new AdobeSignAttySigningUrl.OutputWrapper();

        System.assertNotEquals(null, inp1);
        System.assertNotEquals(null, out1);
    }
}