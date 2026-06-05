@isTest
public class ZccMonthlyCallTest {
    
    private class MockHttpResponseSuccess implements HttpCalloutMock {
        public HTTPResponse respond(HTTPRequest req) {
            HttpResponse res = new HttpResponse();
            res.setStatusCode(200);
            res.setBody('{"queues":[{"queue_id":"Q1","cc_queue_id":"CCQ1","queue_name":"Support","total_inbound":50,"total_completed":30,"total_transferred_out":10,"voice":{"total_missed":5,"long_abandoned":3,"hold_abandoned":2}}],"from":"2023-01-01T00:00:00Z","to":"2023-01-30T23:59:59Z","total_records":1}');
            return res;
        }
    }

    private class MockHttpResponseError implements HttpCalloutMock {
        public HTTPResponse respond(HTTPRequest req) {
            HttpResponse res = new HttpResponse();
            res.setStatusCode(400);
            res.setBody('{"error": "Bad Request"}');
            return res;
        }
    }

    @isTest
    static void testGetReportsWithNullAccessToken() {
        Test.startTest();
        ZccMonthlyCall.getReports();
        Test.stopTest();
        
        List<Zcc_Queue_Monthly_Metrics__c> records = [SELECT Id FROM Zcc_Queue_Monthly_Metrics__c];
        System.assertEquals(0, records.size(), 'No records should have been processed with null access token');
    }

    @isTest
    static void testMakeReportCalloutWithErrorResponse() {
        Test.setMock(HttpCalloutMock.class, new MockHttpResponseError());

        Test.startTest();
        ZccMonthlyCall.makeReportCallout('mockAccessToken');
        Test.stopTest();

        List<Zcc_Queue_Monthly_Metrics__c> records = [SELECT Id FROM Zcc_Queue_Monthly_Metrics__c];
        System.assertEquals(0, records.size(), 'No records should be processed on error response');
    }

    @isTest
    static void testProcessResponseDataWithMissingVoiceData() {
        String responseBody = '{"queues":[{"queue_id":"Q1","cc_queue_id":"CCQ1","queue_name":"Support"}],"from":"2023-01-01T00:00:00Z","to":"2023-01-30T23:59:59Z","total_records":1}';

        Test.startTest();
        ZccMonthlyCall.processResponseData(responseBody);
        Test.stopTest();

        List<Zcc_Queue_Monthly_Metrics__c> records = [SELECT Id, Total_Missed_Monthly__c FROM Zcc_Queue_Monthly_Metrics__c];
        System.assertEquals(1, records.size(), 'One record should have been inserted');
        System.assertEquals(null, records[0].Total_Missed_Monthly__c, 'Total_Missed_Monthly__c should be null for missing voice data');
    }
}