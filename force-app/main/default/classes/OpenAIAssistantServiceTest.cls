@isTest
Public  class OpenAIAssistantServiceTest {
    @isTest
    private static void createThreadTest() {
        Test.setMock(HttpCalloutMock.class, new OpenAIAssistantServiceMock(false));
        String res=OpenAIAssistantService.createThread();
        system.assert(res.length()>0);
    }
    @isTest
    private static void sendMessageAndRunTest() {
        Test.setMock(HttpCalloutMock.class, new OpenAIAssistantServiceMock(false));
        String res=OpenAIAssistantService.sendMessageAndRun('threadId','What color is the sky?');
        system.assert(res.length()>0);
    }
    @isTest
    private static void pollRunStatusTest() {
        Test.setMock(HttpCalloutMock.class, new OpenAIAssistantServiceMock(false));
        String res=OpenAIAssistantService.pollRunStatus('threadId','runId');
        system.assert(res.length()>0);
    }
    @isTest
    private static void getAssistantMessagesTest() {
        Test.setMock(HttpCalloutMock.class, new OpenAIAssistantServiceMock(false));
        String res=OpenAIAssistantService.getAssistantMessages('threadId');
        system.assert(res.length()>0);
    }

    @isTest
    private static void createThreadErrorTest() {
        Test.setMock(HttpCalloutMock.class, new OpenAIAssistantServiceMock(true));
        try {
            String res=OpenAIAssistantService.createThread();
            System.assert(false); // failed the test                     
        } catch (Exception e){
            System.assert(e.getMessage().contains('Script-thrown exception'));
            List <errorlog__c> errors=[select id from errorlog__c];
            System.assertEquals (1, errors.size());
        }
    }
    @isTest
    private static void sendMessageAndRunErrorTest() {
        Test.setMock(HttpCalloutMock.class, new OpenAIAssistantServiceMock(true));            
        try {
            String res=OpenAIAssistantService.sendMessageAndRun('threadId','What color is the sky?');
            System.assert(false); // failed the test                       
        } catch (Exception e){
            System.assert(e.getMessage().contains('Script-thrown exception'));
            List <errorlog__c> errors=[select id from errorlog__c];
            System.assertEquals (1, errors.size());
        }               
    }
    @isTest
    private static void pollRunStatusErrorTest() {
        Test.setMock(HttpCalloutMock.class, new OpenAIAssistantServiceMock(true));            
        try {
            String res=OpenAIAssistantService.pollRunStatus('threadId','runId');
            System.assert(false); // failed the test                       
        } catch (Exception e){
            System.assert(e.getMessage().contains('Script-thrown exception'));
            List <errorlog__c> errors=[select id from errorlog__c];
            System.assertEquals (1, errors.size());
        }
    }
    @isTest
    private static void getAssistantMessagesErrorTest() {
        Test.setMock(HttpCalloutMock.class, new OpenAIAssistantServiceMock(true));           
        try {
            String res=OpenAIAssistantService.getAssistantMessages('threadId');
            System.assert(false); // failed the test                        
        } catch (Exception e){
            System.assert(e.getMessage().contains('Script-thrown exception'));
            List <errorlog__c> errors=[select id from errorlog__c];
            System.assertEquals (1, errors.size());
        }
    }    

    public class OpenAIAssistantServiceMock implements HttpCalloutMock {
        private Boolean throwError=false;
        private OpenAIAssistantServiceMock(Boolean throwError){
            if (throwError) { this.throwError=true;  }
        }

        public HTTPResponse respond(HTTPRequest req) {
            // Create a mock response
            HttpResponse res = new HttpResponse();
            res.setBody('{ "status": "Error",  "results": []  }');  // default response is failure
            res.setStatusCode(500);
            res.setHeader('Content-Type', 'application/json');
            if(this.throwError) {   return res;  }
            if  (   req.getEndPoint().contains('oauth2/token')  && req.getMethod().equals('POST') ) {
                res.setBody('{"access_token":"SESSION_ID_REMOVEDxxxxxxx","instance_url":"https://scilearn--k12config.my.salesforce.com","id":"https://test.salesforce.com/id/00D020000008aMMEAY/00580000001qudPAAQ","token_type":"Bearer","issued_at":"1634598114936","signature":"JEbiEns2MOjK9Rq4d0flFsyoHay/9TtHj3jss/+Yc4Y="}');
                res.setStatus('OK');
                res.setStatusCode(200);
                //for the REST API callout to get asset information from the legacy SciLearn instance:
            } else if (req.getEndPoint().contains('messages') && req.getMethod().equals('POST')){ //Add user message to thread
                res.setBody('{ "id": "msg_vzF1YoVkLsZL6aYhFY1ATIzL",  "object": "thread.message",  "created_at": 1753384264,  "assistant_id": null,  "thread_id": "thread_UApJbptt1hkSBJq3OoEtCujp",  "run_id": null,  "role": "user",  "content": [    {      "type": "text",      "text": {        "value": "How long will my case take?",        "annotations": []      }    }  ],  "attachments": [],  "metadata": {}}');
                res.setStatus('OK');
                res.setStatusCode(200);
            }
            else if (req.getEndPoint().contains('runs') && req.getMethod().equals('POST')){ //Start a Run
                res.setBody('{  "id": "run_iC57GEbNKnFmkhn7rTPl0fo1",  "object": "thread.run",  "created_at": 1753384264,  "assistant_id": "asst_SaBSizxL9u1iUGdCD10VQHQN",  "thread_id": "thread_UApJbptt1hkSBJq3OoEtCujp",  "status": "queued",  "started_at": null,  "expires_at": 1753384864,  "cancelled_at": null,  "failed_at": null,  "completed_at": null,  "required_action": null,  "last_error": null,  "model": "gpt-4o",  "instructions": "You are a family law specialist for Modern Family Law. Provide brief, concise, practical information on divorce, custody, support, and property division. Use clear language and 1-2 sentences. Mention this is general information, not legal advice. Suggest consulting with their Modern Family Law attorney for specific case questions. Maintain a professional, compassionate tone.",  "tools": [    {      "type": "code_interpreter"    },    {      "type": "file_search",      "file_search": {        "ranking_options": {          "ranker": "default_2024_08_21",          "score_threshold": 0.0        }      }    }  ],  "tool_resources": {},  "metadata": {},  "temperature": 1.0,  "top_p": 1.0,  "reasoning_effort": null,  "max_completion_tokens": null,  "max_prompt_tokens": null,  "truncation_strategy": {    "type": "auto",    "last_messages": null  },  "incomplete_details": null,  "usage": null,  "response_format": {    "type": "text"  },  "tool_choice": "auto",  "parallel_tool_calls": true}');
                res.setStatus('OK');
                res.setStatusCode(200);
            } 
            else if (req.getEndPoint().contains('runs/') && req.getMethod().equals('GET')){ //Poll for a response
                res.setBody('{  "id": "run_iC57GEbNKnFmkhn7rTPl0fo1",  "object": "thread.run", "created_at": 1753384264,  "assistant_id": "asst_SaBSizxL9u1iUGdCD10VQHQN",  "thread_id": "thread_UApJbptt1hkSBJq3OoEtCujp",  "status": "completed",  "started_at": 1753384265,  "expires_at": null,  "cancelled_at": null,  "failed_at": null,  "completed_at": 1753384271,  "required_action": null,  "last_error": null,  "model": "gpt-4o",  "instructions": "You are a family law specialist for Modern Family Law. Provide brief, concise, practical information on divorce, custody, support, and property division. Use clear language and 1-2 sentences. Mention this is general information, not legal advice. Suggest consulting with their Modern Family Law attorney for specific case questions. Maintain a professional, compassionate tone.",  "tools": [    {      "type": "code_interpreter"    },    {      "type": "file_search",      "file_search": {        "ranking_options": {          "ranker": "default_2024_08_21",          "score_threshold": 0.0        }      }    }  ],  "tool_resources": {},  "metadata": {},  "temperature": 1.0,  "top_p": 1.0,  "reasoning_effort": null,  "max_completion_tokens": null,  "max_prompt_tokens": null,  "truncation_strategy": {    "type": "auto",    "last_messages": null  },  "incomplete_details": null,  "usage": {    "prompt_tokens": 16851,    "completion_tokens": 121,    "total_tokens": 16972,    "prompt_token_details": {      "cached_tokens": 0    },    "completion_tokens_details": {      "reasoning_tokens": 0    }  },  "response_format": {    "type": "text"  },  "tool_choice": "auto",  "parallel_tool_calls": true}');
                res.setStatus('OK');
                res.setStatusCode(200);
            } 
            else if (req.getEndPoint().contains('messages') && req.getMethod().equals('GET')){ //Get Assistant Message
                res.setBody('{  "object": "list",  "data": [    {      "id": "msg_wwHoFcWy6tfZ7icbJCov9RJt",      "object": "thread.message",      "created_at": 1753384270,      "assistant_id": "asst_SaBSizxL9u1iUGdCD10VQHQN",      "thread_id": "thread_UApJbptt1hkSBJq3OoEtCujp",      "run_id": "run_iC57GEbNKnFmkhn7rTPl0fo1",      "role": "assistant",      "content": [        {          "type": "text",          "text": {            "value": "The length of a family law case can vary significantly depending on several factors, including the complexity of the issues involved, the cooperation between parties, and the court\'s schedule. It\'s not uncommon for a case to take several months to even years to resolve. For an estimation specific to your situation, please consult with your Modern Family Law attorney【4:0†MFL_Content.docx】.",            "annotations": [              {                "type": "file_citation",                "text": "【4:0†MFL_Content.docx】",                "start_index": 368,                "end_index": 390,                "file_citation": {                  "file_id": "file-6qrUrgjvBkqgmR4kCrBKZ2"                }              }            ]          }        }      ],      "attachments": [],      "metadata": {}    },    {      "id": "msg_vzF1YoVkLsZL6aYhFY1ATIzL",      "object": "thread.message",      "created_at": 1753384264,      "assistant_id": null,      "thread_id": "thread_UApJbptt1hkSBJq3OoEtCujp",      "run_id": null,      "role": "user",      "content": [        {          "type": "text",          "text": {            "value": "How long will my case take?",            "annotations": []          }        }      ],      "attachments": [],      "metadata": {}    }  ],  "first_id": "msg_wwHoFcWy6tfZ7icbJCov9RJt",  "last_id": "msg_vzF1YoVkLsZL6aYhFY1ATIzL",  "has_more": false}');            
                res.setStatus('OK');
                res.setStatusCode(200);
            }                                   
            else {  //create a thread 
                res.setBody('{  "id": "thread_UApJbptt1hkSBJq3OoEtCujp",  "object": "thread",  "created_at": 1753384086,  "metadata": {},  "tool_resources": {}}');
                res.setStatus('OK');
                res.setStatusCode(200);
            }        
            return res;
        }
    }    
}