/**
 * @description Test class for AdobeFaErrorLogUtil
 */
@isTest
private class AdobeFaErrorLogUtil_Test {
    
    @TestSetup
    static void setupTestData() {
        insert new Account(Name = 'Test Account');
    }
    
    @isTest
    static void testLogError() {
        Account acc = [SELECT Id FROM Account LIMIT 1];
        
        Test.startTest();
        
        // Test basic logError
        try {
            Integer x = 1/0;
        } catch (Exception ex) {
            AdobeFaErrorLogUtil.logError('TestClass', 'testMethod', ex, acc.Id);
        }
        
        // Test full logError with all ErrorType values
        try {
            throw new TypeException('Config error');
        } catch (Exception ex) {
            AdobeFaErrorLogUtil.logError('TestClass', 'method2', ex, acc.Id, 500, 
                'Request details', AdobeFaErrorLogUtil.ErrorType.CONFIGURATION_ERROR);
        }
        
        try {
            throw new IllegalArgumentException('Data error');
        } catch (Exception ex) {
            AdobeFaErrorLogUtil.logError('TestClass', 'method3', ex, acc.Id, null, 
                null, AdobeFaErrorLogUtil.ErrorType.DATA_ERROR);
        }
        
        try {
            throw new CalloutException('API error');
        } catch (Exception ex) {
            AdobeFaErrorLogUtil.logError('TestClass', 'method4', ex, acc.Id, null, 
                null, AdobeFaErrorLogUtil.ErrorType.API_ERROR);
        }
        
        Test.stopTest();
        
        List<ErrorLog__c> logs = [SELECT ErrorType__c, HTTP_Status_Code__c, 
                                  Request_Details__c FROM ErrorLog__c ORDER BY CreatedDate];
        Assert.areEqual(4, logs.size());
        Assert.areEqual('SYSTEM_ERROR', logs[0].ErrorType__c);
        Assert.areEqual('CONFIGURATION_ERROR', logs[1].ErrorType__c);
        Assert.areEqual(500, logs[1].HTTP_Status_Code__c);
        Assert.areEqual('DATA_ERROR', logs[2].ErrorType__c);
        Assert.areEqual('API_ERROR', logs[3].ErrorType__c);
    }
    
    @isTest
    static void testLogApiError() {
        Account acc = [SELECT Id FROM Account LIMIT 1];
        
        HttpResponse response = new HttpResponse();
        response.setStatusCode(401);
        response.setBody('{"error":"Unauthorized"}');
        
        Test.startTest();
        AdobeFaErrorLogUtil.logApiError('TestClass', 'callout', response, acc.Id, 'Request body');
        Test.stopTest();
        
        ErrorLog__c log = [SELECT HTTP_Status_Code__c, ErrorType__c FROM ErrorLog__c LIMIT 1];
        Assert.areEqual(401, log.HTTP_Status_Code__c);
        Assert.areEqual('API_ERROR', log.ErrorType__c);
    }
    
    @isTest
    static void testCreateErrorTask() {
        Account acc = [SELECT Id FROM Account LIMIT 1];
        User user = [SELECT Id FROM User WHERE Id = :UserInfo.getUserId()];
        
        Test.startTest();
        AdobeFaErrorLogUtil.createErrorTask(acc.Id, 'Error Subject', 'Error Description', user.Id);
        AdobeFaErrorLogUtil.createErrorTask(acc.Id, 'Error Subject 2', 'Description', null);
        Test.stopTest();
        
        List<Task> tasks = [SELECT Status, Priority, ActivityDate FROM Task];
        Assert.areEqual(2, tasks.size());
        Assert.areEqual('Open', tasks[0].Status);
        Assert.areEqual('High', tasks[0].Priority);
        Assert.areEqual(Date.today(), tasks[0].ActivityDate);
    }
    
    @isTest
    static void testErrorHandling() {
        Test.startTest();
        try {
            Integer x = 1/0;
        } catch (Exception ex) {
            AdobeFaErrorLogUtil.logError('TestClass', 'testMethod', ex, null);
        }
        AdobeFaErrorLogUtil.createErrorTask(null, 'Subject', 'Description', null);
        Test.stopTest();
        
        Assert.isTrue([SELECT COUNT() FROM ErrorLog__c] > 0);
    }
}