public with sharing class timesolvIntegrationClientInvoker {

    @InvocableMethod(
        label='Invoke TimeSolv Integration (Queueable)'
        description='Enqueues the timesolvIntegrationClientCall with the given Account Ids'
    )
    public static List<FlowOutput> invokeTimesolvCall(List<FlowInput> inputList) {
        // 1) Gather all unique Account Ids
        Set<Id> accountIds = new Set<Id>();
        for (FlowInput input : inputList) {
            if (input.accountId != null) {
                accountIds.add(input.accountId);
            }
        }

        // 2) Enqueue the job if we have at least one Account Id
        if (!accountIds.isEmpty()) {
            timesolvIntegrationClientCall job = new timesolvIntegrationClientCall(new List<Id>(accountIds));
            System.enqueueJob(job);
        }

        // 3) Return some message or status back to Flow
        List<FlowOutput> outputs = new List<FlowOutput>();
        for (FlowInput fi : inputList) {
            FlowOutput out = new FlowOutput();
            out.message = 'TimeSolv creation queued for Account: ' + fi.accountId;
            outputs.add(out);
        }
        return outputs;
    }

    // Define the input structure Flow will pass in
    public class FlowInput {
        @InvocableVariable(required=true)
        public Id accountId;
    }

    // Define the output structure returned to Flow
    public class FlowOutput {
        @InvocableVariable
        public String message;
    }
}