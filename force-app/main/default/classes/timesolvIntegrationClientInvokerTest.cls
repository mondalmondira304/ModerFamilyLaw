/**
 * @description Test class for timesolvIntegrationClientInvoker
 * @author      Sanders
 * @date        2025-05-01
 */
@isTest(SeeAllData=false)
private class timesolvIntegrationClientInvokerTest {

    /**
     * @description Tests invokeTimesolvCall with a single valid Account Id
     */
    @isTest static void testInvokeWithSingleAccount() {
        // Set up a test Account
        Account acct = new Account(Name='Test Account');
        insert acct;

        // Prepare FlowInput
        timesolvIntegrationClientInvoker.FlowInput input = new timesolvIntegrationClientInvoker.FlowInput();
        input.accountId = acct.Id;
        List<timesolvIntegrationClientInvoker.FlowInput> inputs = new List<timesolvIntegrationClientInvoker.FlowInput>{ input };

        Test.startTest();
            List<timesolvIntegrationClientInvoker.FlowOutput> outputs =
                timesolvIntegrationClientInvoker.invokeTimesolvCall(inputs);
        Test.stopTest();

        // Verify one output and correct message
        System.assertEquals(1, outputs.size(), 'Expected one FlowOutput');
        String expected = 'TimeSolv creation queued for Account: ' + acct.Id;
        System.assertEquals(expected, outputs[0].message);
    }

    /**
     * @description Tests invokeTimesolvCall with an input whose accountId is null
     */
    @isTest static void testInvokeWithNullAccountId() {
        // Prepare FlowInput with null Id
        timesolvIntegrationClientInvoker.FlowInput input = new timesolvIntegrationClientInvoker.FlowInput();
        input.accountId = null;
        List<timesolvIntegrationClientInvoker.FlowInput> inputs = new List<timesolvIntegrationClientInvoker.FlowInput>{ input };

        Test.startTest();
            List<timesolvIntegrationClientInvoker.FlowOutput> outputs =
                timesolvIntegrationClientInvoker.invokeTimesolvCall(inputs);
        Test.stopTest();

        // Even though no job is enqueued, we still return one output
        System.assertEquals(1, outputs.size(), 'One output per input');
        String expected = 'TimeSolv creation queued for Account: null';
        System.assertEquals(expected, outputs[0].message);
    }

    /**
     * @description Tests invokeTimesolvCall with an empty input list
     */
    @isTest static void testInvokeWithEmptyList() {
        List<timesolvIntegrationClientInvoker.FlowInput> inputs = new List<timesolvIntegrationClientInvoker.FlowInput>();

        Test.startTest();
            List<timesolvIntegrationClientInvoker.FlowOutput> outputs =
                timesolvIntegrationClientInvoker.invokeTimesolvCall(inputs);
        Test.stopTest();

        // No inputs → no outputs
        System.assertEquals(0, outputs.size(), 'Expected no outputs for empty input');
    }
}