@isTest
public class HubSpotBatchTest {
    // Mock class to simulate HTTP responses
    private class HubSpotCalloutMock implements HttpCalloutMock {
        private Integer statusCode;
        private String responseBody;

        public HubSpotCalloutMock(Integer statusCode, String responseBody) {
            this.statusCode = statusCode;
            this.responseBody = responseBody;
        }

        public HTTPResponse respond(HTTPRequest req) {
            HttpResponse res = new HttpResponse();
            res.setStatusCode(statusCode);
            res.setBody(responseBody);
            return res;
        }
    }

    @isTest
    static void testBatchWithSuccessfulSubmission() {
        // Insert test data
        List<DelayedFormSubmission__c> submissions = new List<DelayedFormSubmission__c>();
        for (Integer i = 0; i < 10; i++) {
            submissions.add(new DelayedFormSubmission__c(
                Email__c = 'test' + i + '@example.com',
                Status__c = 'Pending'
            ));
        }
        insert submissions;

        // Set mock HTTP response to simulate success
        Test.setMock(HttpCalloutMock.class, new HubSpotCalloutMock(200, '{"status":"OK"}'));

        // Run the batch
        Test.startTest();
        Database.executeBatch(new HubSpotBatch(), 10); // Set the batch size to match the number of records
        Test.stopTest();

        // Verify that all submissions were processed
        List<DelayedFormSubmission__c> processedSubmissions = [SELECT Id, Status__c FROM DelayedFormSubmission__c];
        for (DelayedFormSubmission__c submission : processedSubmissions) {
            System.assertEquals('Processed', submission.Status__c);
        }
    }

    @isTest
    static void testBatchWithFailedSubmission() {
        // Insert test data
        List<DelayedFormSubmission__c> submissions = new List<DelayedFormSubmission__c>();
        for (Integer i = 0; i < 10; i++) {
            submissions.add(new DelayedFormSubmission__c(
                Email__c = 'test' + i + '@example.com',
                Status__c = 'Pending'
            ));
        }
        insert submissions;

        // Set mock HTTP response to simulate failure
        Test.setMock(HttpCalloutMock.class, new HubSpotCalloutMock(400, '{"status":"Error"}'));

        // Run the batch
        Test.startTest();
        Database.executeBatch(new HubSpotBatch(), 10); // Set the batch size to match the number of records
        Test.stopTest();

        // Verify that all submissions have error status
        List<DelayedFormSubmission__c> processedSubmissions = [SELECT Id, Status__c, Error_Message__c FROM DelayedFormSubmission__c];
        for (DelayedFormSubmission__c submission : processedSubmissions) {
            System.assertEquals('Error', submission.Status__c);
            System.assertNotEquals(null, submission.Error_Message__c);
        }
    }

    @isTest
    static void testBatchWithException() {
        // Insert test data
        List<DelayedFormSubmission__c> submissions = new List<DelayedFormSubmission__c>();
        for (Integer i = 0; i < 10; i++) {
            submissions.add(new DelayedFormSubmission__c(
                Email__c = 'test' + i + '@example.com',
                Status__c = 'Pending'
            ));
        }
        insert submissions;

        // Set mock HTTP response to simulate an exception
        Test.setMock(HttpCalloutMock.class, new HubSpotCalloutMock(500, '{"status":"Exception"}'));

        // Run the batch
        Test.startTest();
        Database.executeBatch(new HubSpotBatch(), 10); // Set the batch size to match the number of records
        Test.stopTest();

        // Verify that all submissions have error status due to exception
        List<DelayedFormSubmission__c> processedSubmissions = [SELECT Id, Status__c, Error_Message__c FROM DelayedFormSubmission__c];
        for (DelayedFormSubmission__c submission : processedSubmissions) {
            System.assertEquals('Error', submission.Status__c);
            System.assertNotEquals(null, submission.Error_Message__c);
        }
    }
}