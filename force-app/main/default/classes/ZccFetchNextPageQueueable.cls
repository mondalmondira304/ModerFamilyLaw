public class ZccFetchNextPageQueueable implements Queueable, Database.AllowsCallouts {
    private String nextPageToken;
    private String accessToken;
    private String fromDate;
    private String toDate;
    private Id queueSummaryId;

    public ZccFetchNextPageQueueable(String nextPageToken, String accessToken, String fromDate, String toDate, Id queueSummaryId) {
        this.nextPageToken = nextPageToken;
        this.accessToken = accessToken;
        this.fromDate = fromDate;
        this.toDate = toDate;
        this.queueSummaryId = queueSummaryId;
    }

    public void execute(QueueableContext context) {
    try {
        Integer executionDepth = Limits.getQueueableJobs();
        System.debug('🚀 Queueable Job Execution Depth: ' + executionDepth);

        if (executionDepth >= 5) {
            System.debug('❌ Stopping execution to prevent infinite recursion.');
            return;
        }

        // Proceed with normal API call logic
       String endpoint = 'https://api.zoom.us/v2/contact_center/analytics/historical/details/metrics'
                + '?page_size=100'
                + '&channel_types=voice'
                + '&timezone=America/Denver'
                + '&from=' + fromDate
                + '&to=' + toDate
                + '&next_page_token=' + nextPageToken;

        HttpRequest req = new HttpRequest();
        req.setMethod('GET');
        req.setEndpoint(endpoint);
        req.setHeader('Authorization', 'Bearer ' + accessToken);
        req.setHeader('Accept', 'application/json');

        Http http = new Http();
        HttpResponse res = http.send(req);
        
        if (res.getStatusCode() == 200) {
            Map<String, Object> responseMap = (Map<String, Object>) JSON.deserializeUntyped(res.getBody());
            if (responseMap == null) {
                System.debug('❌ Response map is null. Exiting.');
                return;
            }

            List<Zcc_Queue_Call_Details__c> recordsToInsert = ZccDailyDetailCalls.processResponseData(res.getBody(), queueSummaryId);
            String newNextPageToken = (String) responseMap.get('next_page_token');

            if (!recordsToInsert.isEmpty()) {
                System.enqueueJob(new ZccInsertRecordsQueueable(
                    recordsToInsert,
                    queueSummaryId,
                    newNextPageToken,
                    accessToken,
                    fromDate,
                    toDate
                ));
                System.debug('✅ Enqueued insert queueable for fetched page with ' + recordsToInsert.size() + ' records.');
            } else {
                if (!String.isBlank(newNextPageToken)) {
                    System.enqueueJob(new ZccFetchNextPageQueueable(
                        newNextPageToken,
                        accessToken,
                        fromDate,
                        toDate,
                        queueSummaryId
                    ));
                    System.debug('⚡ No records, but chaining next page fetch.');
                } else {
                    System.debug('✅ No records and no next page token. Pagination complete.');
                }
            }
        } else {
            System.debug('❌ FetchNextPage callout error: ' + res.getStatusCode() + ' - ' + res.getStatus());
        }
    } catch (Exception e) {
        System.debug('❌ Exception in ZccFetchNextPageQueueable: ' + e.getMessage());
    }
}

}