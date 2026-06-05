public class ZccDailyDetailCalls {

    public static void getReports() {
        // Refresh the access token and call the future method
        String accessToken = ZoomTokenUtility.refreshAccessToken();
        System.debug('Access Token Retrieved: ' + accessToken);

        if (accessToken == null) {
            System.debug('Failed to retrieve valid access token.');
            return;
        }

        makeReportCallout(accessToken);
    }

    @future(callout=true)
    public static void makeReportCallout(String accessToken) {
        // We'll store our summary record here
        Zcc_Call_Queue_Summary__c queueSummary = new Zcc_Call_Queue_Summary__c();

        try {
            // 1) Set up date range for the report (yesterday only)
            DateTime currentDate = DateTime.now();  // This is in the running user's time zone
            DateTime yesterday = currentDate.addDays(-1);

            // 2) Explicitly set start (00:00:00) and end (23:59:59) for yesterday
            DateTime fromDateTime = DateTime.newInstance(yesterday.year(), yesterday.month(), yesterday.day(), 0, 0, 0);
            DateTime toDateTime   = DateTime.newInstance(yesterday.year(), yesterday.month(), yesterday.day(), 23, 59, 59);

            // 3) Format dates for the API call in America/Denver, appending 'Z'
            //    per your snippet. (Zoom often wants ISO-8601, but your snippet uses 'Z'.)
            String fromDate = fromDateTime.format('yyyy-MM-dd\'T\'HH:mm:ss\'Z\'', 'America/Denver');
            String toDate   = toDateTime.format('yyyy-MM-dd\'T\'HH:mm:ss\'Z\'', 'America/Denver');

            System.debug('Daily Report Date Range - From: ' + fromDate + ', To: ' + toDate);

            // 4) Construct the endpoint URL and set up the HTTP request
            String endpoint =
                'https://api.zoom.us/v2/contact_center/analytics/historical/details/metrics' +
                '?channel_types=voice' +
                '&timezone=America/Denver' +
                '&page_size=100' +
                '&from=' + fromDate +
                '&to=' + toDate;

            System.debug('Daily Request Endpoint: ' + endpoint);

            HttpRequest req = new HttpRequest();
            req.setMethod('GET');
            req.setEndpoint(endpoint);
            req.setHeader('Authorization', 'Bearer ' + accessToken);
            req.setHeader('Accept', 'application/json');

            // 5) Make the callout
            Http http = new Http();
            HttpResponse res = http.send(req);

            if (res.getStatusCode() == 200) {
                System.debug('Response is successful. Processing first page data.');
                Map<String, Object> responseMap = (Map<String, Object>) JSON.deserializeUntyped(res.getBody());
                if (responseMap == null) {
                    System.debug('Response map is null. Exiting.');
                    return;
                }

                // Create summary record
                queueSummary.Next_Page_Token__c = (String) responseMap.get('next_page_token');
                queueSummary.Page_Size__c       = (Integer) responseMap.get('page_size');
                queueSummary.Total_Records__c   = (Integer) responseMap.get('total_records');

                // Store the actual DateTimes (so you can see them in SF)
                queueSummary.From__c     = fromDateTime;
                queueSummary.To__c       = toDateTime;
                queueSummary.Timezone__c = (String) responseMap.get('timezone');

                insert queueSummary;
                System.debug('ZCC_LOG | Summary Record Inserted: ' + queueSummary);

                // Process the first page of detail records
                List<Zcc_Queue_Call_Details__c> recordsToInsert =
                    processResponseData(res.getBody(), queueSummary.Id);

                String nextPageToken = (String) responseMap.get('next_page_token');
                System.debug('ZCC_LOG | next_page_token: ' + nextPageToken);
                System.debug('ZCC_LOG | Number of records to insert on first page: ' + recordsToInsert.size());

                // If we have detail records, enqueue the queueable for insertion
                if (!recordsToInsert.isEmpty()) {
                    System.enqueueJob(
                        new ZccInsertRecordsQueueable(
                            recordsToInsert,
                            queueSummary.Id,
                            nextPageToken,
                            accessToken,
                            fromDate,
                            toDate
                        )
                    );
                    System.debug('Enqueued first queueable job for ' + recordsToInsert.size() + ' records.');
                } else {
                    System.debug('No detail records found on the first page.');
                }
            } else {
                System.debug('Callout Error: ' + res.getStatusCode() + ' - ' + res.getStatus());
                System.debug('Callout Body: ' + res.getBody()); // Check for JSON error details from Zoom
            }

        } catch (Exception e) {
            System.debug('Exception in makeReportCallout: ' + e.getMessage());
        }
    }

    public static List<Zcc_Queue_Call_Details__c> processResponseData(String responseBody, Id parentId) {
        List<Zcc_Queue_Call_Details__c> callDetailRecords = new List<Zcc_Queue_Call_Details__c>();
        Map<String, Object> responseMap = (Map<String, Object>) JSON.deserializeUntyped(responseBody);

        if (responseMap != null && responseMap.containsKey('details')) {
            List<Object> details = (List<Object>) responseMap.get('details');
            System.debug('Number of details in response: ' + details.size());

            for (Object detailObj : details) {
                Map<String, Object> detail = (Map<String, Object>) detailObj;
                Zcc_Queue_Call_Details__c callDetail = new Zcc_Queue_Call_Details__c();

                // Populate fields from the response
                if (detail.containsKey('queues')) {
                    List<Object> queues = (List<Object>) detail.get('queues');
                    if (queues != null && !queues.isEmpty()) {
                        Map<String, Object> queue = (Map<String, Object>) queues[0];
                        callDetail.Queue_Id__c    = (String) queue.get('queue_id');
                        callDetail.CC_Queue_Id__c = (String) queue.get('cc_queue_id');
                        callDetail.Queue_Name__c  = (String) queue.get('queue_name');
                    }
                }
                // Process Agents
                if (detail.containsKey('agents')) {
                    List<Object> agents = (List<Object>) detail.get('agents');
                    List<String> agentNameList = new List<String>();
                    for (Object agentObj : agents) {
                        Map<String, Object> agent = (Map<String, Object>) agentObj;
                        if (agent.containsKey('display_name')) {
                            agentNameList.add((String) agent.get('display_name'));
                        }
                    }
                    callDetail.Intake_Name__c = String.join(agentNameList, ', ');
                }
                // Other fields
                callDetail.Engagement_Id__c    = (String) detail.get('engagement_id');
                callDetail.Start_Time__c       = (String) detail.get('start_time');
                callDetail.Direction__c        = (String) detail.get('direction');
                callDetail.Call_Summary__c     = parentId;
                callDetail.Consumer_Number__c  = (String) detail.get('consumer_number');
                callDetail.Results__c          = (String) detail.get('results');
                callDetail.Total_Duration__c   = (Integer) detail.get('total_duration');
                callDetail.IVR_Duration__c     = (Integer) detail.get('ivr_duration');
                callDetail.Waiting_Duration__c = (Integer) detail.get('waiting_duration');
                callDetail.Talking_Duration__c = (Integer) detail.get('talking_duration');
                callDetail.Hold_Duration__c    = (Integer) detail.get('hold_duration');
                callDetail.Wrap_Up_Duration__c = (Integer) detail.get('wrap_up_duration');
                callDetail.Total_Flow_Duration__c = (Integer) detail.get('total_flow_duration');
                callDetail.Queue_Wait_Type__c  = (String) detail.get('queue_wait_type');
                callDetail.Last_Widget_Name__c = (String) detail.get('last_widget_name');
                callDetail.Ring_Duration__c    = (Integer) detail.get('ring_duration');

                // Handle Dialed Numbers
                if (detail.containsKey('dialed_numbers')) {
                    List<Object> dialedNumbers = (List<Object>) detail.get('dialed_numbers');
                    if (dialedNumbers != null && !dialedNumbers.isEmpty()) {
                        List<String> stringDialedNumbers = new List<String>();
                        for (Object dialedNumber : dialedNumbers) {
                            stringDialedNumbers.add((String) dialedNumber);
                        }
                        callDetail.Dialed_Numbers__c = String.join(stringDialedNumbers, ', ');
                    }
                }
                callDetailRecords.add(callDetail);
            }
        } else {
            System.debug('No "details" key found in response.');
        }
        return callDetailRecords;
    }
}