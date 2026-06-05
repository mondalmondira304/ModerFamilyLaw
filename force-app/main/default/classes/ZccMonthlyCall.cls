public class ZccMonthlyCall {

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
            DateTime currentDate = DateTime.now();
            DateTime previousDate = currentDate.addDays(-1);

            // Ensure times are set explicitly
            DateTime fromDateTime = DateTime.newInstance(currentDate.year(), currentDate.month(), 1, 0, 0, 0);
            DateTime toDateTime = DateTime.newInstance(previousDate.year(), previousDate.month(), previousDate.day(), 23, 59, 59);

            // Debugging: log the exact times being used
            System.debug('Calculated From DateTime: ' + fromDateTime.format('yyyy-MM-dd\'T\'HH:mm:ss\'Z\'', 'America/Denver'));
            System.debug('Calculated To DateTime: ' + toDateTime.format('yyyy-MM-dd\'T\'HH:mm:ss\'Z\'', 'America/Denver'));

            // Format dates for the API with America/Denver timezone
            String fromDate = fromDateTime.format('yyyy-MM-dd\'T\'HH:mm:ss\'Z\'', 'America/Denver');
            String toDate = toDateTime.format('yyyy-MM-dd\'T\'HH:mm:ss\'Z\'', 'America/Denver');

            // Construct the endpoint URL with America/Denver timezone
            String endpoint = 'https://api.zoom.us/v2/contact_center/analytics/historical/queues/metrics?channel_types=voice&timezone=America/Denver&page_size=100&from=' + fromDate + '&to=' + toDate;
            System.debug('Request Endpoint: ' + endpoint);

            HttpRequest req = new HttpRequest();
            req.setMethod('GET');
            req.setEndpoint(endpoint);
            req.setHeader('Authorization', 'Bearer ' + accessToken);
            req.setHeader('Accept', 'application/json');

            // Send the request
            Http http = new Http();
            HttpResponse res = http.send(req);

            // Log the response
            System.debug('Response Status Code: ' + res.getStatusCode());
            System.debug('Response Body: ' + res.getBody());

            // Process the response data if the callout was successful
            if (res.getStatusCode() == 200) {
                processResponseData(res.getBody());
            } else {
                System.debug('Error: ' + res.getStatusCode() + ' - ' + res.getStatus() + '. Response Body: ' + res.getBody());
            }
        } catch (Exception e) {
            System.debug('Exception: ' + e.getMessage());
        }
    }

    // Method to process the response data and perform DML operations after the callout
    public static void processResponseData(String responseBody) {
        System.debug('Processing Response Data: ' + responseBody);
        Map<String, Object> responseMap = (Map<String, Object>) JSON.deserializeUntyped(responseBody);

        if (responseMap != null && responseMap.containsKey('queues')) {
            // Step 1: Delete all existing records in Zcc_Queue_Monthly_Metrics__c (after the callout)
            deleteAllMonthlyRecords();

            // Step 2: Prepare new records for insertion
            List<Object> queues = (List<Object>) responseMap.get('queues');
            List<Zcc_Queue_Monthly_Metrics__c> queueDetailRecords = new List<Zcc_Queue_Monthly_Metrics__c>();

            for (Object queueObj : queues) {
                if (queueObj instanceof Map<String, Object>) {
                    Map<String, Object> queue = (Map<String, Object>) queueObj;

                    Zcc_Queue_Monthly_Metrics__c queueDetail = new Zcc_Queue_Monthly_Metrics__c();
                    queueDetail.From__c = parseIsoDateTime((String) responseMap.get('from'));
                    queueDetail.To__c = parseIsoDateTime((String) responseMap.get('to'));
                    queueDetail.Total_Records_Monthly__c = (Integer) responseMap.get('total_records');
                    queueDetail.External_ID__c = (String) queue.get('queue_id');
                    queueDetail.CC_Queue_ID__c = (String) queue.get('cc_queue_id');
                    queueDetail.Queue_Name__c = (String) queue.get('queue_name');
                    queueDetail.Total_Inbound_Monthly__c = (Integer) queue.get('total_inbound');
                    queueDetail.Total_Completed_Monthly__c = (Integer) queue.get('total_completed');
                    queueDetail.Total_Transferred_Out_Monthly__c   = (Integer) queue.get('total_transferred_out');


                    if (queue.containsKey('voice') && queue.get('voice') instanceof Map<String, Object>) {
                        Map<String, Object> voice = (Map<String, Object>) queue.get('voice');
                        queueDetail.Total_Missed_Monthly__c = (Integer) voice.get('total_missed');
                        queueDetail.Long_Abandoned_Monthly__c = (Integer) voice.get('long_abandoned');
                        queueDetail.Hold_Abandoned_Monthly__c = (Integer) voice.get('hold_abandoned');
                       queueDetail.Short_Abandoned_Monthly__c   = (Integer) voice.get('short_abandoned');

                    }

                    queueDetailRecords.add(queueDetail);
                }
            }

            // Step 3: Insert the new records after deleting old ones
            if (!queueDetailRecords.isEmpty()) {
                insert queueDetailRecords;
                System.debug('Inserted ' + queueDetailRecords.size() + ' Monthly Call Detail records.');
            }
        }
    }

    // Helper method to delete all existing records in Zcc_Queue_Monthly_Metrics__c after the callout
    public static void deleteAllMonthlyRecords() {
        try {
            // Query all records in Zcc_Queue_Monthly_Metrics__c
            List<Zcc_Queue_Monthly_Metrics__c> existingRecords = [
                SELECT Id FROM Zcc_Queue_Monthly_Metrics__c
            ];

            // Delete all records if any exist
            if (!existingRecords.isEmpty()) {
                delete existingRecords;
                System.debug('Deleted ' + existingRecords.size() + ' existing Monthly Call Detail records.');
            } else {
                System.debug('No existing records found to delete.');
            }
        } catch (Exception e) {
            System.debug('Error deleting existing Monthly Call Detail records: ' + e.getMessage());
        }
    }

    // Helper method to parse ISO DateTime format
    public static DateTime parseIsoDateTime(String isoDateStr) {
        if (String.isBlank(isoDateStr)) {
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