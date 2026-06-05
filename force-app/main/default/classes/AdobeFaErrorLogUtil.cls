/**
 * @description Utility class for logging Adobe Sign FA Portal errors to ErrorLog custom object
 */
public class AdobeFaErrorLogUtil {
    
    public enum ErrorType {
        API_ERROR,
        CONFIGURATION_ERROR,
        DATA_ERROR,
        SYSTEM_ERROR
    }
    
    public static void logError(
        String className,
        String methodName,
        Exception ex,
        Id relatedRecordId
    ) {
        logError(className, methodName, ex, relatedRecordId, null, null, null);
    }
    
    public static void logError(
        String className,
        String methodName,
        Exception ex,
        Id relatedRecordId,
        Integer httpStatusCode,
        String requestDetails,
        ErrorType errorType
    ) {
        try {
            ErrorLog__c log = new ErrorLog__c(
                Name = className + '.' + methodName,
                Class_Name__c = className,
                Method_Name__c = methodName,
                ErrorMessage__c = ex.getMessage(),
                ErrorStackTrace__c = ex.getStackTraceString(),
                Related_Account__c  = relatedRecordId,
                Integration_Name__c = 'Adobe FA Portal',
                HTTP_Status_Code__c = httpStatusCode,
                Request_Details__c = requestDetails,
                ErrorType__c = errorType != null ? errorType.name() : 'SYSTEM_ERROR'
            );
            
            insert log;
            
        } catch (Exception loggingEx) {
            System.debug(LoggingLevel.ERROR,
                'AdobeFaErrorLogUtil.logError: Failed to create error log: ' + loggingEx.getMessage()
            );
        }
    }
    
    public static void logApiError(
        String className,
        String methodName,
        HttpResponse response,
        Id relatedRecordId,
        String requestBody
    ) {
        String errorMessage = 'API call failed with status ' + response.getStatusCode() +
                              '. Response: ' + response.getBody();
        
        ErrorLog__c log = new ErrorLog__c(
            Name = className + '.' + methodName,
            Class_Name__c = className,
            Method_Name__c = methodName,
            ErrorMessage__c = errorMessage,
            Related_Account__c  = relatedRecordId,
            Integration_Name__c = 'Adobe FA Portal',
            HTTP_Status_Code__c = response.getStatusCode(),
            Request_Details__c = requestBody,
            ErrorType__c = 'API_ERROR'
        );
        
        try {
            insert log;
        } catch (Exception ex) {
            System.debug(LoggingLevel.ERROR,
                'AdobeFaErrorLogUtil.logApiError: Failed to create error log: ' + ex.getMessage()
            );
        }
    }
    
    public static void createErrorTask(
        Id relatedRecordId,
        String subject,
        String description,
        Id assignToUserId
    ) {
        try {
            Task errorTask = new Task(
                WhatId = relatedRecordId,
                Subject = subject,
                Description = description,
                Status = 'Open',
                Priority = 'High',
                ActivityDate = Date.today()
            );
            
            if (assignToUserId != null) {
                errorTask.OwnerId = assignToUserId;
            }
            
            insert errorTask;
            
        } catch (Exception ex) {
            System.debug(LoggingLevel.ERROR,
                'AdobeFaErrorLogUtil.createErrorTask: Failed to create task: ' + ex.getMessage()
            );
        }
    }
}