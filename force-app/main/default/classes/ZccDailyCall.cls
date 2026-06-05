public class ZccDailyCall {

    public static void getReports() {
        // Step 1: Refresh access token
        String accessToken = ZoomTokenUtility.refreshAccessToken();
        System.debug('Access Token Retrieved: ' + accessToken);

        if (accessToken == null) {
            System.debug('Failed to retrieve valid access token.');
            return; // Exit if no valid token is available
        }

        // Step 2: Call the async method to perform the callout
        makeReportCallout(accessToken);
    }

    // Asynchronous method to make the actual callout
    @future(callout=true)
    public static void makeReportCallout(String accessToken) {
        try {
            // Set up date range for the report (Yesterday only)
            DateTime currentDate = DateTime.now();
            DateTime yesterday = currentDate.addDays(-1);

           // Set explicit times for the start (00:00) and end (23:59) of the day
DateTime fromDateTime = DateTime.newInstance(yesterday.year(), yesterday.month(), yesterday.day(), 0, 0, 0);
DateTime toDateTime = DateTime.newInstance(yesterday.year(), yesterday.month(), yesterday.day(), 23, 59, 59);

// Format dates for the API with America/Denver timezone
String fromDate = fromDateTime.format('yyyy-MM-dd\'T\'HH:mm:ss\'Z\'', 'America/Denver');
String toDate = toDateTime.format('yyyy-MM-dd\'T\'HH:mm:ss\'Z\'', 'America/Denver');
System.debug('Daily Report Date Range - From: ' + fromDate + ', To: ' + toDate);

// Construct the URL and set up the HTTP request
String endpoint = 'https://api.zoom.us/v2/contact_center/analytics/historical/queues/metrics?channel_types=voice&timezone=America/Denver&page_size=100&from=' + fromDate + '&to=' + toDate;
System.debug('Daily Request Endpoint: ' + endpoint);

            HttpRequest req = new HttpRequest();
            req.setMethod('GET');
            req.setEndpoint(endpoint);
            req.setHeader('Authorization', 'Bearer ' + accessToken);
            req.setHeader('Accept', 'application/json');

            // Send the request
            Http http = new Http();
            HttpResponse res = http.send(req);

            // Log the response
            System.debug('Daily Response Status Code: ' + res.getStatusCode());
            System.debug('Daily Response Body: ' + res.getBody());

            // Only proceed if the response is successful
            if (res.getStatusCode() == 200) {
                System.debug('Daily response is successful. Processing response data.');
                processResponseData(res.getBody());
            } else {
                System.debug('Daily Callout Error: ' + res.getStatusCode() + ' - ' + res.getStatus() + '. Response Body: ' + res.getBody());
            }
        } catch (Exception e) {
            System.debug('Exception in daily makeReportCallout: ' + e.getMessage());
        }
    }

    // Method to process the response data and perform DML operations
    public static void processResponseData(String responseBody) {
        System.debug('Processing Daily Response Data: ' + responseBody);
        Map<String, Object> responseMap = (Map<String, Object>) JSON.deserializeUntyped(responseBody);

        if (responseMap != null && responseMap.containsKey('queues')) {
            System.debug('Daily response contains "queues" key. Proceeding with data processing.');
            
            // Delete all existing records in Zcc_Queue_Daily_Metrics__c
            deleteAllDailyRecords();

            // Prepare new records for insertion
            List<Object> queues = (List<Object>) responseMap.get('queues');
            System.debug('Number of queues in daily response: ' + queues.size());
            
            List<Zcc_Queue_Daily_Metrics__c> queueDetailRecords = new List<Zcc_Queue_Daily_Metrics__c>();

            for (Object queueObj : queues) {
                if (queueObj instanceof Map<String, Object>) {
                    Map<String, Object> queue = (Map<String, Object>) queueObj;

                    System.debug('Processing queue for daily report: ' + queue.get('queue_name'));
                    
                    Zcc_Queue_Daily_Metrics__c queueDetail = new Zcc_Queue_Daily_Metrics__c();
                    queueDetail.From__c = parseIsoDateTime((String) responseMap.get('from'));
                    queueDetail.To__c = parseIsoDateTime((String) responseMap.get('to'));
                    queueDetail.Total_Records_Daily__c = (Integer) responseMap.get('total_records');
                    queueDetail.External_ID__c = (String) queue.get('queue_id');
                    queueDetail.CC_Queue_ID__c = (String) queue.get('cc_queue_id');
                    queueDetail.Queue_Name__c = (String) queue.get('queue_name');
                    queueDetail.Total_Inbound_Daily__c = (Integer) queue.get('total_inbound');
                    queueDetail.Total_Completed_Daily__c = (Integer) queue.get('total_completed');
                    queueDetail.Total_Transferred_Out_Daily__c = (Integer) queue.get('total_transferred_out');

                    if (queue.containsKey('voice') && queue.get('voice') instanceof Map<String, Object>) {
                        Map<String, Object> voice = (Map<String, Object>) queue.get('voice');
                        queueDetail.Total_Missed_Daily__c = (Integer) voice.get('total_missed');
                        queueDetail.Total_Overflowed_Daily__c = (Integer) voice.get('total_overflowed');
                        queueDetail.Long_Abandoned_Daily__c = (Integer) voice.get('long_abandoned');
                        queueDetail.Hold_Abandoned_Daily__c = (Integer) voice.get('hold_abandoned');
                        queueDetail.Short_Abandoned_Daily__c  = (Integer) voice.get('short_abandoned');

                        System.debug('Voice metrics for daily queue: ' + queue.get('queue_name') + ' - Missed: ' + voice.get('total_missed') + ', Overflowed: ' + voice.get('total_overflowed') + ', Long Abandoned: ' + voice.get('long_abandoned') + ', Hold Abandoned: ' + voice.get('hold_abandoned'));
                    }

                    queueDetailRecords.add(queueDetail);
                }
            }

            // Insert the new records after deleting old ones
            if (!queueDetailRecords.isEmpty()) {
                insert queueDetailRecords;
                System.debug('Inserted ' + queueDetailRecords.size() + ' Daily Call Detail records.');
            } else {
                System.debug('No records prepared for daily insertion.');
            }
        } else {
            System.debug('No "queues" key found in daily response.');
        }
    }

    public static void deleteAllDailyRecords() {
        try {
            List<Zcc_Queue_Daily_Metrics__c> existingRecords = [
                SELECT Id FROM Zcc_Queue_Daily_Metrics__c
            ];

            if (!existingRecords.isEmpty()) {
                delete existingRecords;
                System.debug('Deleted ' + existingRecords.size() + ' existing Daily Call Detail records.');
            } else {
                System.debug('No existing records found to delete for daily report.');
            }
        } catch (Exception e) {
            System.debug('Error deleting existing Daily Call Detail records: ' + e.getMessage());
        }
    }

    public static DateTime parseIsoDateTime(String isoDateStr) {
        if (String.isBlank(isoDateStr)) {
            System.debug('ISO date string is blank.');
            return null;
        }

        if (isoDateStr.endsWith('Z')) {
            isoDateStr = isoDateStr.substring(0, isoDateStr.length() - 1);
        }

        String formattedDateStr = isoDateStr.replace('T', ' ');

        try {
            return DateTime.valueOf(formattedDateStr);
        } catch (Exception e) {
            System.debug('Failed to parse DateTime: ' + isoDateStr + ' with error: ' + e.getMessage());
            return null;
        }
    }
}