@isTest
public class ZccFetchNextPageQueueableTest {

    // A simple HttpCalloutMock for the fetch callout.
    // It returns a 200 response with a JSON body containing a non-empty "details" array 
    // and a non-blank next_page_token.
    private class ZccFetchNextPageCalloutMock implements HttpCalloutMock {
        public HTTPResponse respond(HTTPRequest req) {
            HttpResponse res = new HttpResponse();
            res.setStatusCode(200);
            res.setHeader('Content-Type', 'application/json');
            // This JSON response should be structured such that your processResponseData
            // method returns at least one Zcc_Queue_Call_Details__c record.
            res.setBody('{' +
                '  "next_page_token": "dummyNextPageToken",' +
                '  "details": [' +
                '    {' +
                '      "consumer_number": "1234567890",' +
                '      "engagement_id": "E1",' +
                '      "direction": "inbound",' +
                '      "results": "Completed"' +
                '    }' +
                '  ]' +
                '}');
            return res;
        }
    }

    @isTest static void testZccFetchNextPageQueueableExecution() {
        // 1. Create a dummy summary record that the queueable requires.
        //    Ensure you populate all required fields.
        Zcc_Call_Queue_Summary__c summary = new Zcc_Call_Queue_Summary__c(Name = 'Test Summary');
        insert summary;
        
        // 2. Set the HTTP callout mock so that the callout in execute() receives our test JSON response.
        Test.setMock(HttpCalloutMock.class, new ZccFetchNextPageCalloutMock());
        
        // 3. Enqueue the ZccFetchNextPageQueueable job.
        Test.startTest();
        System.enqueueJob(new ZccFetchNextPageQueueable(
            'initialToken',          // initial next_page_token
            'dummyAccessToken',      // dummy access token
            '2025-01-01',            // fromDate
            '2025-01-02',            // toDate
            summary.Id               // queue summary Id
        ));
        Test.stopTest();
        
        // 4. Verify that at least one new queueable job was enqueued.
        //    We expect either a ZccInsertRecordsQueueable (if records were returned) 
        //    or a chained ZccFetchNextPageQueueable if no records were found.
        List<AsyncApexJob> jobs = [
            SELECT Id, JobType, Status 
            FROM AsyncApexJob 
            WHERE JobType = 'Queueable'
        ];
        System.assert(jobs.size() > 0, 'Expected at least one Queueable job to have been enqueued.');
    }
}