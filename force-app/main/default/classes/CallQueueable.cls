public class CallQueueable implements Queueable, Database.AllowsCallouts {
    private String callType;

    // Constructor to specify the call type (e.g., 'daily', 'monthly', or 'detail')
    public CallQueueable(String callType) {
        this.callType = callType;
    }

    public void execute(QueueableContext context) {
        // Step 1: Refresh the access token
        String accessToken = ZoomTokenUtility.refreshAccessToken();
        System.debug('Access Token Retrieved in Queueable: ' + accessToken);

        if (accessToken != null) {
            // Step 2: Execute the appropriate call based on callType
            if (callType == 'daily') {
                System.debug('Executing daily callout...');
                ZccDailyCall.makeReportCallout(accessToken);

            } else if (callType == 'monthly') {
                System.debug('Executing monthly callout...');
                ZccMonthlyCall.makeReportCallout(accessToken);

            } else if (callType == 'detail') {
                System.debug('Executing detail callout...');
                // This calls into your ZccDailyDetailCalls class
                ZccDailyDetailCalls.makeReportCallout(accessToken);

            } else {
                System.debug('Invalid callType specified: ' + callType);
            }
        } else {
            System.debug('Failed to retrieve valid access token in Queueable.');
        }
    }
}