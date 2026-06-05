@isTest
global class ZccDailyDetailCallsTest implements HttpCalloutMock {

    // The mock logic for each endpoint
    global HttpResponse respond(HttpRequest req) {
        HttpResponse res = new HttpResponse();
        
        // 1) Mock token refresh endpoint
        if (req.getEndpoint().contains('zoom.us/oauth/token')) {
            res.setHeader('Content-Type', 'application/json');
            res.setBody('{"access_token":"mockAccessTokenValue","refresh_token":"mockRefreshToken"}');
            res.setStatusCode(200);
            return res;
        }
        
        // 2) Mock the first-page analytics response
        //    (no 'next_page_token' param in the URL yet)
        if (req.getEndpoint().contains('analytics/historical/details')
            && !req.getEndpoint().contains('next_page_token')) 
        {
            res.setHeader('Content-Type', 'application/json');
            res.setBody(
                '{' +
                '  "next_page_token":"testToken",' +
                '  "page_size":100,' +
                '  "total_records":1,' +
                '  "timezone":"America/Denver",' +
                '  "details":[' +
                '    {' +
                '      "queues":[{"queue_id":"Q1","cc_queue_id":"CC1","queue_name":"Test Queue"}],' +
                '      "agents":[{"display_name":"Agent A"}],' +
                '      "engagement_id":"E1",' +
                '      "start_time":"2025-02-27T12:00:00Z",' +
                '      "direction":"inbound",' +
                '      "consumer_number":"+17203226338",' +
                '      "results":"Completed",' +
                '      "total_duration":120,' +
                '      "ivr_duration":30,' +
                '      "waiting_duration":10,' +
                '      "talking_duration":70,' +
                '      "hold_duration":5,' +
                '      "wrap_up_duration":5,' +
                '      "total_flow_duration":10,' +
                '      "queue_wait_type":"Type1",' +
                '      "last_widget_name":"Widget1",' +
                '      "ring_duration":5,' +
                '      "dialed_numbers":["+17203226338"]' +
                '    }' +
                '  ]' +
                '}'
            );
            res.setStatusCode(200);
            return res;
        }
        
        // 3) Mock the second-page analytics response
        //    (URL has next_page_token=testToken)
        if (req.getEndpoint().contains('analytics/historical/details')
            && req.getEndpoint().contains('next_page_token=testToken')) 
        {
            res.setHeader('Content-Type', 'application/json');
            // Return no details and an empty next_page_token to end pagination
            res.setBody(
                '{' +
                '  "next_page_token":"",' +
                '  "page_size":100,' +
                '  "total_records":1,' +
                '  "timezone":"America/Denver",' +
                '  "details":[]' +
                '}'
            );
            res.setStatusCode(200);
            return res;
        }
        
        // 4) Fallback for unexpected endpoints
        res.setStatusCode(400);
        res.setBody('{"message":"Unknown endpoint in test mock"}');
        return res;
    }
    
    @isTest
    static void testMakeReportCallout() {
        // Register this class as the mock for all callouts
        Test.setMock(HttpCalloutMock.class, new ZccDailyDetailCallsTest());
        
        Test.startTest();
            // Call your main entry method (this triggers the first call + next page flow)
            ZccDailyDetailCalls.getReports();
        Test.stopTest();
        
        // Verify exactly one summary record was created
        List<Zcc_Call_Queue_Summary__c> summaries = [
            SELECT Id, Next_Page_Token__c, Total_Records__c
            FROM Zcc_Call_Queue_Summary__c
        ];
        System.assertEquals(1, summaries.size(), 'Should have 1 summary record');
        System.assertEquals('testToken', summaries[0].Next_Page_Token__c, 'Next page token mismatch');
        
        // Verify exactly one detail record was inserted
        List<Zcc_Queue_Call_Details__c> details = [
            SELECT Id, Consumer_Number__c
            FROM Zcc_Queue_Call_Details__c
        ];
        System.assertEquals(1, details.size(), 'Should have 1 detail record');
        System.assertEquals('+17203226338', details[0].Consumer_Number__c, 'Consumer number mismatch');
    }
}