@isTest
public with sharing class NetDocumentsFileAPITest {
    @testSetup
    static void setupData() {
        // Create test Account
        Integer random=Integer.valueOf(Math.random() * 1000);
        Integer i=Integer.valueOf(Math.random() * 1000);        
        Account acc = 
            new Account(
                FirstName= 'Test FN-' + i +random,
                LastName='Test LN-' + i + random,
                PersonEmail= 'test-' + i + random + '@example.com',
                PersonMobilePhone='5101112222',
                Responsible_Attorney__c=UserInfo.getUserId(),
                Responsible_Paralegal__c=UserInfo.getUserId() ,
                Quoted_Retainer__c=10,
                Type_of_Case_A__c='Divorce w/Children',
                Timesolv_Client_Id__c='9999T',
                Timesolv_Matter_Id__c='001',
                State_A__c='COLORADO'
                );
        insert acc;
        Account opposingparty= new Account(FirstName= 'Test FN-'+i,LastName='Test LN-'+i,PersonEmail= 'test-'+i +  '@example.com');
        insert opposingparty;        
        Jurisdiction__c jur = new Jurisdiction__c (name='Texas', city__c='Dallas', state__c='Texas');
        insert jur;
        MFL_Office__c office = new MFL_Office__c(Name='Test Office', State__c='California');
        insert office;
        Matters__c matter1 = new Matters__c(Name = 'Test '+i, hire_date__c=System.Date.Today(),  Status__c='Open', Primary_Attorney__c=UserInfo.getUserId(),
            Client_Name__c=acc.Id, Opposing_Party_a__c=opposingparty.id, MFL_Office__c=office.id,  //office is a required field
            Matter_ID_Client__c=i.format(), Matter_ID_Matter__c='001');   
        insert matter1;     
    }
    // Mock for successful response
    private class SuccessMock implements HttpCalloutMock {
        public HttpResponse respond(HttpRequest req) {
            HttpResponse res = new HttpResponse();
            res.setStatusCode(200);
            res.setBody('{"status":"OK"}');
            return res;
        }
    }
    // Mock for HTTP error (non-200) response
    private class ErrorMock implements HttpCalloutMock {
        public HttpResponse respond(HttpRequest req) {
            HttpResponse res = new HttpResponse();
            res.setStatusCode(400);
            res.setBody('Bad Request');
            return res;
        }
    }
    // Mock for HTTP not found response
    private class NotFoundMock implements HttpCalloutMock {
        public HttpResponse respond(HttpRequest req) {
            HttpResponse res = new HttpResponse();
            res.setStatusCode(404);
            res.setBody('Not Found');
            return res;
        }
    }    
    // Mock that simulates an exception in the callout
    private class ExceptionMock implements HttpCalloutMock {
        public HttpResponse respond(HttpRequest req) {
            // You can throw any exception type here
            throw new CalloutException('Simulated callout failure');
        }
    }
    @isTest
    static void testGetDefaultingValue() {
        Jurisdiction__c jur=[Select id, state__c from jurisdiction__c where state__c='Texas'][0];
        MFL_Office__c office=[Select id, State__c from MFL_Office__c where state__c='California'][0];
        Matters__c mat=[SELECT Id, Name, Matter_ID_Client__c, Matter_ID_Matter__c, Case_Type__c, 
            jurisdiction__c, jurisdiction__r.state__c,
            Petitioner__r.lastname, Petitioner__r.firstname,
            Client_Name__r.lastname, 	Client_Name__r.firstname,
            MFL_Office__c, MFL_office__r.state__c 
            FROM Matters__c][0];
        /*office.State__c=null;
        update office;               
        mat.jurisdiction__c=jur.id;
        update mat;          
        System.assertEquals('TEX', NetDocumentsFileAPI.getDefaultingValue(mat)); //retrieves from Jurisdiction*/
        office.State__c='California';
        update office;          
        mat.jurisdiction__c=null;
        update mat;                     
        System.assertEquals('CAL', NetDocumentsFileAPI.getDefaultingValue(mat));  //retrieves from office
    }    
    @isTest
    static void testGetDefaultingValueAccount() {
        Jurisdiction__c jur=[Select id, state__c from jurisdiction__c where state__c='Texas'][0];
        MFL_Office__c office=[Select id, State__c from MFL_Office__c where state__c='California'][0];
        Account acct=[SELECT Id, Name, firstname, lastname, Timesolv_Client_Number__c, Timesolv_Matter_Id__c, Type_of_Case_A__c,
                    Responsible_Office__c, State_A__c,
                    Responsible_Paralegal__r.Email, Responsible_Attorney__r.Email, Responsible_Paralegal__r.Id, Responsible_Attorney__r.Id 
                    FROM Account][0];                    
        System.assertEquals('COL', NetDocumentsFileAPI.getDefaultingValue(acct));  
    }      
    @isTest
    static void testCheckWorkspace(){
        Jurisdiction__c jur=[Select id, state__c from jurisdiction__c where state__c='Texas'][0];
        Matters__c mat=[SELECT Id, Name, Matter_ID_Client__c, Matter_ID_Matter__c, Case_Type__c, 
            jurisdiction__c, jurisdiction__r.state__c,
            Petitioner__r.lastname, Petitioner__r.firstname,
	        Client_Name__r.lastname, 	Client_Name__r.firstname,            
            MFL_Office__c, MFL_office__r.state__c 
            FROM Matters__c][0];
        mat.jurisdiction__c=jur.id;
        update mat;      
        Test.setMock(HttpCalloutMock.class, new SuccessMock());
        System.Test.startTest();
            Boolean result= NetDocumentsFileAPI.checkWorkspace(mat, 'respositoryvalue','cabinetValue');
        System.Test.stopTest();
        System.assertEquals(true, result);
    }
    @isTest
    static void testCheckWorkspaceForAccount(){
        Account acct=[SELECT Id, Name, firstname, lastname, Timesolv_Client_Number__c, Timesolv_Matter_Id__c, Type_of_Case_A__c,
                    Responsible_Office__c, State_A__c,
                    Responsible_Paralegal__r.Email, Responsible_Attorney__r.Email, Responsible_Paralegal__r.Id, Responsible_Attorney__r.Id 
                    FROM Account][0];      
        Test.setMock(HttpCalloutMock.class, new SuccessMock());
        System.Test.startTest();
            Boolean result= NetDocumentsFileAPI.checkWorkspace(acct, 'respositoryvalue','cabinetValue');
        System.Test.stopTest();
        System.assertEquals(true, result);
    }    
    @isTest
    static void testCheckClientIdNotFound(){
        Jurisdiction__c jur=[Select id, state__c from jurisdiction__c where state__c='Texas'][0];
        Matters__c mat=[SELECT Id, Name, Matter_ID_Client__c, Matter_ID_Matter__c, Case_Type__c, 
            jurisdiction__c, jurisdiction__r.state__c,
            Petitioner__r.lastname, Petitioner__r.firstname,
	        Client_Name__r.lastname, 	Client_Name__r.firstname,            
            MFL_Office__c, MFL_office__r.state__c 
            FROM Matters__c][0];
        mat.jurisdiction__c=jur.id;
        update mat;      
        Test.setMock(HttpCalloutMock.class, new NotFoundMock());
        NetDocumentsFileAPI.NetDocsClient clientInstance = new NetDocumentsFileAPI.NetDocsClient(mat);
        System.Test.startTest();
            Boolean result= NetDocumentsFileAPI.checkClientId(clientInstance, 'respositoryvalue');  //will not find the client and then creates it
        System.Test.stopTest();
        System.assertEquals(false, result);  //since we don't have a way to switch the mock to success as the API calls are nested
    }    
    @isTest
    static void testCheckClientIdNotPopulated(){
        Jurisdiction__c jur=[Select id, state__c from jurisdiction__c where state__c='Texas'][0];
        Matters__c mat=[SELECT Id, Name, Matter_ID_Client__c, Matter_ID_Matter__c, Case_Type__c, 
            jurisdiction__c, jurisdiction__r.state__c,
            Petitioner__r.lastname, Petitioner__r.firstname,
	        Client_Name__r.lastname, 	Client_Name__r.firstname,            
            MFL_Office__c, MFL_office__r.state__c 
            FROM Matters__c][0];
        mat.jurisdiction__c=jur.id;
        mat.Matter_ID_Client__c=null;
        update mat;      
        Test.setMock(HttpCalloutMock.class, new NotFoundMock());
        NetDocumentsFileAPI.NetDocsClient clientInstance = new NetDocumentsFileAPI.NetDocsClient(mat);
        System.Test.startTest();
            Boolean result= NetDocumentsFileAPI.checkClientId(clientInstance, 'repositoryvalue');  //will not find the client and then creates it
        System.Test.stopTest();
        System.assertEquals(false, result);  //client id has to be populated on the matter
    }      
    @isTest
    static void testCheckMatterIdNotFound(){
        Jurisdiction__c jur=[Select id, state__c from jurisdiction__c where state__c='Texas'][0];
        Matters__c mat=[SELECT Id, Name, Matter_ID_Client__c, Matter_ID_Matter__c, Case_Type__c, 
            jurisdiction__c, jurisdiction__r.state__c,
            Petitioner__r.lastname, Petitioner__r.firstname,
	        Client_Name__r.lastname, 	Client_Name__r.firstname,            
            MFL_Office__c, MFL_office__r.state__c 
            FROM Matters__c][0];
        mat.jurisdiction__c=jur.id;
        update mat;      
        Test.setMock(HttpCalloutMock.class, new NotFoundMock());
        NetDocumentsFileAPI.NetDocsMatter matInstance = new NetDocumentsFileAPI.NetDocsMatter(mat);
        System.Test.startTest();
            Boolean result= NetDocumentsFileAPI.checkMatterId(matInstance, 'respositoryvalue');  //will not find the matter and then creates it
        System.Test.stopTest();
        System.assertEquals(false, result);  //since we don't have a way to switch the mock to success as the API calls are nested
    }      
    @isTest
    static void testCheckMatterIdNotPopulated(){
        Jurisdiction__c jur=[Select id, state__c from jurisdiction__c where state__c='Texas'][0];
        Matters__c mat=[SELECT Id, Name, Matter_ID_Client__c, Matter_ID_Matter__c, Case_Type__c, 
            jurisdiction__c, jurisdiction__r.state__c,
            Petitioner__r.lastname, Petitioner__r.firstname,
	        Client_Name__r.lastname, 	Client_Name__r.firstname,            
            MFL_Office__c, MFL_office__r.state__c 
            FROM Matters__c][0];
        mat.jurisdiction__c=jur.id;
        mat.Matter_ID_Matter__c=null;
        update mat;      
        Test.setMock(HttpCalloutMock.class, new NotFoundMock());
        NetDocumentsFileAPI.NetDocsMatter matInstance = new NetDocumentsFileAPI.NetDocsMatter(mat);        
        System.Test.startTest();
            Boolean result= NetDocumentsFileAPI.checkMatterId(matInstance, 'repositoryvalue');  //will not find the matter and then creates it
        System.Test.stopTest();
        System.assertEquals(false, result);  //matter id has to be populated on the matter
    }        
    @isTest
    static void testUploadFileSuccess() {
        // Set the HTTP mock to return a success response
        Test.setMock(HttpCalloutMock.class, new SuccessMock());
        List<Matters__c> matters=
                    [SELECT Id, Name, Matter_ID_Client__c, Matter_ID_Matter__c, Case_Type__c, 
                    Petitioner__r.lastname, Petitioner__r.firstname,
	                Client_Name__r.lastname, 	Client_Name__r.firstname,                                    
                    jurisdiction__c, jurisdiction__r.state__c,  //needed to determine the workspace template
                    MFL_Office__c, MFL_office__r.state__c, //needed to determine the workspace template
                    Primary_Paralegal__r.Email, Primary_Attorney__r.Email, Primary_Paralegal__r.Id, Primary_Attorney__r.Id //needed to attach a task record to a matter
                    FROM Matters__c ];
        // Call the method
        System.Test.startTest();
            Boolean result = NetDocumentsFileAPI.uploadFile(
                matters[0],
                'TestFile.txt',
                Blob.valueOf('Sample data'),
                'MAT-1234',
                'CLT-5678',
                'NG-UBO32328'
            );
        System.Test.stopTest();
        
        // Verify
        System.assert(result, 'Expected uploadFile to return true for a successful callout.');
    }
    @isTest
    static void testUploadFileError() {
        // Set the HTTP mock to return an error response
        Test.setMock(HttpCalloutMock.class, new ErrorMock());
        List<Matters__c> matters=
                    [SELECT Id, Name, Matter_ID_Client__c, Matter_ID_Matter__c, Case_Type__c, 
                    Petitioner__r.lastname, Petitioner__r.firstname,
                    Client_Name__r.lastname, 	Client_Name__r.firstname,                
                    jurisdiction__c, jurisdiction__r.state__c,  //needed to determine the workspace template
                    MFL_Office__c, MFL_office__r.state__c, //needed to determine the workspace template
                    Primary_Paralegal__r.Email, Primary_Attorney__r.Email, Primary_Paralegal__r.Id, Primary_Attorney__r.Id //needed to attach a task record to a matter
                    FROM Matters__c ];        
        // Call the method
        Boolean result = NetDocumentsFileAPI.uploadFile(
            matters[0],
            'ErrorFile.txt',
            Blob.valueOf('Error data'),
            'MAT-9999',
            'CLT-8888',
            'NG-ERRORCAB'
        );
        // Verify
        System.assertEquals(false, result, 'Expected uploadFile to return false for a non-200 response.');
    }
    @isTest
    static void testUploadFileException() {
        // Set the HTTP mock to throw an exception
        Test.setMock(HttpCalloutMock.class, new ExceptionMock());
        List<Matters__c> matters=
                    [SELECT Id, Name, Matter_ID_Client__c, Matter_ID_Matter__c, Case_Type__c, 
                    Petitioner__r.lastname, Petitioner__r.firstname,
                    Client_Name__r.lastname, 	Client_Name__r.firstname,                
                    jurisdiction__c, jurisdiction__r.state__c,  //needed to determine the workspace template
                    MFL_Office__c, MFL_office__r.state__c, //needed to determine the workspace template
                    Primary_Paralegal__r.Email, Primary_Attorney__r.Email, Primary_Paralegal__r.Id, Primary_Attorney__r.Id //needed to attach a task record to a matter
                    FROM Matters__c ];          
        // Call the method
        Boolean result = NetDocumentsFileAPI.uploadFile(
            matters[0],
            'ExceptionFile.txt',
            Blob.valueOf('Exception data'),
            'MAT-EX123',
            'CLT-EX456',
            'NG-EXCAB'
        );        
        // Verify that it safely returns false instead of propagating the exception
        System.assertEquals(false, result, 'Expected uploadFile to return false when an exception is thrown.');
    }    
    @isTest
    static void testcreateTaskToTrackError(){
        Matters__c matter=
                    [SELECT Id, Name, Matter_ID_Client__c, Matter_ID_Matter__c, Case_Type__c, 
                    Petitioner__r.lastname, Petitioner__r.firstname,                
                    Client_Name__r.lastname, 	Client_Name__r.firstname,
                    jurisdiction__c, jurisdiction__r.state__c,  //needed to determine the workspace template
                    MFL_Office__c, MFL_office__r.state__c, //needed to determine the workspace template
                    Primary_Paralegal__r.Email, Primary_Attorney__r.Email, Primary_Paralegal__r.Id, Primary_Attorney__r.Id //needed to attach a task record to a matter
                    FROM Matters__c ][0];    
        Test.startTest();
            NetDocumentsFileAPI.createTaskToTrackError(matter, '001-001', 'TestFile', 'error');          
        Test.stopTest();
        List<Task> t=[select id, whatid from task where whatId=:matter.id];
        System.assertEquals(1,t.size());
    }    
}