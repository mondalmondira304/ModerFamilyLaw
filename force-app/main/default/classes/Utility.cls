public without sharing class Utility {
    public class ErrorClass{
        @InvocableVariable (label='Exception Message' required=true) public String exceptionMessage;
        @InvocableVariable (label='Stack Trace' required=false) public String stackTrace;
        @InvocableVariable (label='Line Number' required=false) public Integer lineNum;
        @InvocableVariable (label='Line Number' required=false) public String errortype;
        @InvocableVariable (label='Procedure/Method Name' required=true) public String procname;
    }
    @InvocableMethod(label='createErrorRecordForInvocableAction' description='Creates a record in the errorlog__c object.' category='User')
    public static void createErrorRecordForInvocableAction(List<ErrorClass> errors){
        for (ErrorClass e: errors){
            createErrorRecord(e.exceptionMessage, e.stackTrace, e.lineNum, e.errortype, e.procname);  //since there will only be one error at a time, I think that this is acceptable
        }
    } 
    @AuraEnabled @Future //to prevent certain DML related issues for use by LWC controller
    public static void createFutureErrorRecord(string exceptionMessage, String stackTrace, Integer lineNum, String errortype, String procname){
        createErrorRecord(exceptionMessage, stackTrace, lineNum, errortype, procname);
    }    
    @AuraEnabled
    public static void createErrorRecord(string exceptionMessage,String stackTrace, Integer lineNum, String errortype, String procname){
        ErrorLog__c newErrorRecord = new ErrorLog__c();
        newErrorRecord.Name = procname;
        if (exceptionMessage!=null && exceptionMessage.length()>255)
        {	newErrorRecord.ErrorMessage__c = exceptionMessage.substring(0,254);	}
        else
        {	newErrorRecord.ErrorMessage__c = exceptionMessage;	}
        newErrorRecord.ErrorLineNumber__c = lineNum;
        newErrorRecord.ErrorStackTrace__c = stackTrace;
        newErrorRecord.ErrorType__c = errortype;
        database.insert(newErrorRecord,false);
    }

    //user record update for when account email address gets updated
    @future
    public static void updateUserRecords(Map<String,String> emailMap){         
        //init
        List<User> userList = new List<User>();
        List<User> userListUpdate = new List<User>();

        //find user records by old emails and update username and email to new email address
        userList = [SELECT Id, Email, Username FROM User WHERE Username IN :emailMap.keyset()];
        if(!userList.isEmpty()){
            for(User u : userList){
                String em = emailMap.get(u.Email);
                system.debug('em: '+em);
                u.Email = em;
                u.Username = em;
                userListUpdate.add(u);
            }
        }
        if(!userListUpdate.isEmpty()){
            try{
                system.debug('userListUpdate: ' + userListUpdate);
                update userListUpdate;//update user records

                //send password resets
                for(User u : userListUpdate){
                    System.ResetPassword(u.Id, true);
                }
            }
            catch(exception e) {
                system.debug('error: ' + e);
                Utility.createErrorRecord(e.getMessage(), e.getStackTraceString(), e.getLineNumber(), e.getTypeName(), 'AccountTriggerHandler.updateUserRecords');    
            } 
        }
    }
}