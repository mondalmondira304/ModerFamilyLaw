public class NetDocumentsFileUploadQueueable implements Queueable, Database.AllowsCallouts {
    private List<Id> mattersIds;
    private List<Id> contentDocumentLinkIds;
    public NetDocumentsFileUploadQueueable(List<Id> mattersIds, List<Id> contentDocumentLinkIds) {
        this.mattersIds = mattersIds;
        this.contentDocumentLinkIds = contentDocumentLinkIds;
    }
    public void execute(QueueableContext context) {
        try {
            System.debug('NetDocumentsFileUploadQueueable: Starting file upload for Matters IDs: ' + mattersIds);
            // Call the handler method for file upload processing
            NetDocumentsMattersFileTriggerHandler.handleFileUpload(mattersIds, contentDocumentLinkIds);
            System.debug('NetDocumentsFileUploadQueueable: File upload process completed successfully.');
        } catch(exception e) {
            Utility.createErrorRecord(e.getMessage(), e.getStackTraceString(), e.getLineNumber(), e.getTypeName(), 'NetDocumentsFileUploadQueueable.execute');                
        }
    }
    /* Finalizer Implementation TODO
    public void execute(FinalizerContext ctx) {
        if (ctx.getResult() == ParentJobResult.UNHANDLED_EXCEPTION ) {
            Exception ex = ctx.getException();
            String jobId = ctx.getAsyncApexJobId();
            
            // Log Error to Custom Object. TODO
            System.debug('Job ' + jobId + ' failed: ' + ex.getMessage());
            Utility.createErrorRecord(ex.getMessage(), '', 1, '', 'NetDocumentsFileUploadQueueable.execute');  
        }
    }*/

}