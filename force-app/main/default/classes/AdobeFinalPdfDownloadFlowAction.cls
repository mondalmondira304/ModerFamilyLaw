/**
 * @description
 * Flow Action (Invocable) that enqueues AdobeFinalPdfDownloadJob immediately.
 *
 * Why this exists:
 * - You want Flow to trigger the PDF download job without using Apex scheduling logic.
 * - You still plan to use a Scheduled Path in the Record-Triggered Flow (runs as Automated Process),
 *   which avoids common portal-user permission issues when saving Files.
 *
 * What it does:
 * - Accepts AccountId (required)
 * - AgreementId and AgreementName are optional
 * - Enqueues AdobeFinalPdfDownloadJob (attempt 1)
 * - Returns enqueue status + Queueable Job Id
 *
 * Notes:
 * - No scheduling is performed here.
 * - Old classes remain unchanged.
 *
 * @author  Sanders
 * @date    2026-02-10
 */
public without sharing class AdobeFinalPdfDownloadFlowAction {

    private static final String CLASS_NAME = 'AdobeFinalPdfDownloadFlowAction';

    public class FlowParamException extends Exception {}

    public class Request {
        @InvocableVariable(required=true)
        public Id accountId;

        @InvocableVariable(required=false)
        public String agreementId;

        @InvocableVariable(required=false)
        public String agreementName;
    }

    public class Response {
        @InvocableVariable
        public Boolean enqueued;

        @InvocableVariable
        public String message;

        @InvocableVariable
        public Id queueableJobId;
    }

    @InvocableMethod(
        label='Download Final Fee Agreement PDF (Immediate Job)'
        description='Enqueues AdobeFinalPdfDownloadJob immediately. No Apex scheduling is used.'
    )
    public static List<Response> run(List<Request> requests) {
        List<Response> results = new List<Response>();

        if (requests == null || requests.isEmpty()) {
            return results;
        }

        for (Request req : requests) {
            Response out = new Response();
            out.enqueued = false;

            try {
                if (req == null || req.accountId == null) {
                    throw new FlowParamException('Missing required input: accountId');
                }

                Id jobId = System.enqueueJob(
                    new AdobeFinalPdfDownloadJob(
                        req.agreementId,
                        req.agreementName,
                        req.accountId
                    )
                );

                out.enqueued = true;
                out.queueableJobId = jobId;
                out.message = 'Enqueued AdobeFinalPdfDownloadJob successfully.';

            } catch (Exception e) {
                out.enqueued = false;
                out.message  = 'Failed to enqueue job: ' + e.getMessage();

                try {
                    AdobeFaErrorLogUtil.logError(
                        CLASS_NAME,
                        'run',
                        e,
                        (req != null ? req.accountId : null),
                        null,
                        'agreementId=' + (req != null ? req.agreementId : null) +
                        ', agreementName=' + (req != null ? req.agreementName : null),
                        AdobeFaErrorLogUtil.ErrorType.SYSTEM_ERROR
                    );
                } catch (Exception ignore) {
                }
            }

            results.add(out);
        }

        return results;
    }
}