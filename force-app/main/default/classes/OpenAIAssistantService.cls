public with sharing class OpenAIAssistantService {
    @AuraEnabled
    public static String createThread() {
    try {
        HttpRequest req = new HttpRequest();
        req.setEndpoint('callout:OpenAI');
        req.setMethod('POST');
        req.setHeader('Content-Type', 'application/json');
        req.setHeader('OpenAI-Beta', 'assistants=v2');
        req.setBody('{}');   
        Http http = new Http();
        HttpResponse res = http.send(req);
        if (res.getStatusCode() != 200) {
            throw new AuraHandledException('Failed to create thread: ' +'StatusCode:  '+res.getStatusCode());
        }           
        //system.debug(res.getBody());
        return res.getBody();
    } catch(exception e) {
        Utility.createErrorRecord(e.getMessage(), e.getStackTraceString(), e.getLineNumber(), e.getTypeName(), 'OpenAIAssistantService.createThread');    
        throw new AuraHandledException( e.getMessage());
    }
    }

    @AuraEnabled
    public static String sendMessageAndRun(String threadId, String userMessage) {
    try {
        ChatGPTInstruction__mdt ChatGPTInstruction=ChatGPTInstruction__mdt.getInstance('default');
        Http http = new Http();

        // Step 1: Add user message to thread
        HttpRequest req = new HttpRequest();
        req.setEndpoint('callout:OpenAI'+ '/' +threadId + '/messages');        
        req.setMethod('POST');
        req.setHeader('Content-Type', 'application/json');
        req.setHeader('OpenAI-Beta', 'assistants=v2');
        req.setBody(JSON.serialize(new Map<String, Object>{
            'role' => 'user',
            'content' => userMessage
        }));
        HttpResponse msgResponse = http.send(req);
        if (msgResponse.getStatusCode() != 200) {
            throw new AuraHandledException('Failed to add message: ' +'StatusCode:  '+msgResponse.getStatusCode()+ 'threadId: '+ threadId+'  userMessage:  '+userMessage);
        }
        //system.debug('Step 1:  '+msgResponse.getBody());          

        // Step 2: Start a run
        req.setEndpoint('callout:OpenAI'+ '/' + threadId + '/runs');           
        req.setBody(JSON.serialize(new Map<String, Object>{
            'assistant_id' => '{!$Credential.OpenAICredential.assistant_id}',
            'instructions' => ChatGPTInstruction.instruction__c       
        }));
        system.debug('req.getBody()  '+req.getBody());
        HttpResponse runResponse = http.send(req);
        if (runResponse.getStatusCode() != 200) {
            throw new AuraHandledException('Failed to start run: ' +'StatusCode:  '+runResponse.getStatusCode()+ 'threadId: '+ threadId+'  userMessage:  '+userMessage);
        }
        //system.debug('Step 2: '+runResponse.getBody());            
        return runResponse.getBody(); // contains runId and status
    } catch(exception e) {
        Utility.createErrorRecord(e.getMessage(), e.getStackTraceString(), e.getLineNumber(), e.getTypeName(), 'OpenAIAssistantService.sendMessageAndRun');    
        throw new AuraHandledException( e.getMessage());
    }        
    }

    @AuraEnabled
    public static String pollRunStatus(String threadId, String runId) {
    try {
        HttpRequest req = new HttpRequest();
        req.setEndpoint('callout:OpenAI'+ '/' + threadId + '/runs/' + runId);          
        req.setMethod('GET');
        req.setHeader('OpenAI-Beta', 'assistants=v2');
        Http http = new Http();
        HttpResponse res = http.send(req);
        if (res.getStatusCode() != 200) {
            throw new AuraHandledException('Failed to poll status: ' +'StatusCode:  '+res.getStatusCode()+ 'threadId: '+ threadId+'  runId:  '+runId);
        }                
        //system.debug('Polling:  '+res.getBody());        
        return res.getBody(); // Will contain status like "queued", "in_progress", "completed"
    } catch(exception e) {
        Utility.createErrorRecord(e.getMessage(), e.getStackTraceString(), e.getLineNumber(), e.getTypeName(), 'OpenAIAssistantService.pollRunStatus');    
        throw new AuraHandledException( e.getMessage());
    }        
    }

    @AuraEnabled
    public static String getAssistantMessages(String threadId) {
    try {
        HttpRequest req = new HttpRequest();
        req.setEndpoint('callout:OpenAI'+ '/' + threadId + '/messages');        
        req.setMethod('GET');
        req.setHeader('OpenAI-Beta', 'assistants=v2');
        Http http = new Http();
        HttpResponse res = http.send(req);
        if (res.getStatusCode() != 200) {
            throw new AuraHandledException('Failed to get assistant message: ' +'StatusCode:  '+res.getStatusCode()+ 'threadId: '+ threadId);
        }         
        //system.debug('getAssistantMessage:  '+res.getBody());              
        return res.getBody(); // Returns array of messages — we'll parse for the latest assistant message in LWC
    } catch(exception e) {
        Utility.createErrorRecord(e.getMessage(), e.getStackTraceString(), e.getLineNumber(), e.getTypeName(), 'OpenAIAssistantService.getAssistantMessages');    
        throw new AuraHandledException( e.getMessage());
    }        
    }
}