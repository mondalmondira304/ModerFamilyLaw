/**
 * @description
 * Test coverage for AdobeFinalPdfDownloadFlowAction
 * - Covers null/empty input returns
 * - Covers happy path enqueue
 * - Covers validation/catch path
 *
 * Notes:
 * - This class only enqueues a Queueable, so no callout mocks are required here.
 * - We assert the Response fields and basic behavior.
 *
 * @author Sanders
 * @date   2026-02-10
 */
@IsTest
private class AdobeFinalPdfDownloadFlowAction_Test {

    private static Id makeAccount() {
        Account a = new Account(Name = 'AdobeFinalPdfDownloadFlowAction_Test');
        insert a;
        return a.Id;
    }

    @IsTest
    static void returnsEmptyList_whenNullRequests() {
        Test.startTest();
        List<AdobeFinalPdfDownloadFlowAction.Response> res =
            AdobeFinalPdfDownloadFlowAction.run(null);
        Test.stopTest();

        System.assertNotEquals(null, res, 'Should return a list (not null).');
        System.assertEquals(0, res.size(), 'Null input should return empty list.');
    }

    @IsTest
    static void returnsEmptyList_whenEmptyRequests() {
        Test.startTest();
        List<AdobeFinalPdfDownloadFlowAction.Response> res =
            AdobeFinalPdfDownloadFlowAction.run(new List<AdobeFinalPdfDownloadFlowAction.Request>());
        Test.stopTest();

        System.assertNotEquals(null, res, 'Should return a list (not null).');
        System.assertEquals(0, res.size(), 'Empty input should return empty list.');
    }

    @IsTest
    static void happyPath_enqueuesJob() {
        Id accId = makeAccount();

        AdobeFinalPdfDownloadFlowAction.Request req =
            new AdobeFinalPdfDownloadFlowAction.Request();
        req.accountId = accId;
        req.agreementId = 'AGR_TEST_1';
        req.agreementName = 'Test Agreement';

        Test.startTest();
        List<AdobeFinalPdfDownloadFlowAction.Response> res =
            AdobeFinalPdfDownloadFlowAction.run(
                new List<AdobeFinalPdfDownloadFlowAction.Request>{ req }
            );
        Test.stopTest();

        System.assertEquals(1, res.size(), 'Should return one response.');
        System.assertEquals(true, res[0].enqueued, 'Should mark enqueued=true.');
        System.assertNotEquals(null, res[0].queueableJobId, 'Should return the job id.');
        System.assert(
            res[0].message != null && res[0].message.contains('Enqueued'),
            'Message should indicate enqueue success.'
        );
    }

    @IsTest
    static void validationPath_nullReq_isHandled() {
        Test.startTest();
        List<AdobeFinalPdfDownloadFlowAction.Response> res =
            AdobeFinalPdfDownloadFlowAction.run(
                new List<AdobeFinalPdfDownloadFlowAction.Request>{ null }
            );
        Test.stopTest();

        System.assertEquals(1, res.size(), 'Should return one response.');
        System.assertEquals(false, res[0].enqueued, 'Should not enqueue.');
        System.assertEquals(null, res[0].queueableJobId, 'No job id expected.');
        System.assert(
            res[0].message != null && res[0].message.startsWith('Failed to enqueue job:'),
            'Should return a failure message.'
        );
    }

    @IsTest
    static void validationPath_nullAccountId_isHandled() {
        AdobeFinalPdfDownloadFlowAction.Request req =
            new AdobeFinalPdfDownloadFlowAction.Request();
        req.accountId = null;

        Test.startTest();
        List<AdobeFinalPdfDownloadFlowAction.Response> res =
            AdobeFinalPdfDownloadFlowAction.run(
                new List<AdobeFinalPdfDownloadFlowAction.Request>{ req }
            );
        Test.stopTest();

        System.assertEquals(1, res.size(), 'Should return one response.');
        System.assertEquals(false, res[0].enqueued, 'Should not enqueue.');
        System.assertEquals(null, res[0].queueableJobId, 'No job id expected.');
        System.assert(
            res[0].message != null && res[0].message.contains('Missing required input: accountId'),
            'Should indicate missing accountId.'
        );
    }
}