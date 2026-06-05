public without sharing class TaskController {
	public class BadIdException extends Exception {}
    public class TooManyClientPortalTasksException extends Exception {}
    public class ZeroClientPortalTasksException extends Exception {}

    private static String getClientPortalTaskId (String matterid){
        List<Client_Portal_Tasks__c> portalTasks=[select id from Client_Portal_Tasks__c where matter__c=:matterId] ;
        /*if (portalTasks.size()==0)
            { throw new ZeroClientPortalTasksException ('There needs to be one Client Portal Task record associated with the matter but there is none:  '+matterId);  } */
        if (portalTasks.size()>1)
            { throw new TooManyClientPortalTasksException ('There needs to be one Client Portal Task record associated with the matter but there is '+portalTasks.size()+' '+matterId);  }   
        else if (portalTasks.size()==1)  {
            return portalTasks[0].id;
        } else {
            return null;
        }           
    }
    @AuraEnabled
    public static List<Task> getCIFormStatus(String matterId) {
        try {
            String portalClientTasksId=getClientPortalTaskId(matterid);
            List<Task> listOfCIFormTask = [SELECT WhatId, Subject, ci_form__c, Type, Status,ActivityDate FROM Task WHERE (WhatId=:matterId or WhatId=:portalClientTasksId) AND Type = 'CI Form'];            
            if (listOfCIFormTask.size()==0){
                throw new BadIdException('Bad Matter Id submitted:  '+matterId);
            }
            //to handle the additional upload functionality which every matter will have access to
            Task additionalUploadTask= new Task(WhatId=listOfCIFormTask[0].WhatId, Subject='CI Form:  Additional Uploads', ci_form__c='Additional Uploads', type='CI Form', status='Open', ActivityDate =  listOfCIFormTask[0].ActivityDate);
            listOfCIFormTask.add(additionalUploadTask);
            return listOfCIFormTask;
        }catch (Exception e) {
            Utility.createErrorRecord(e.getMessage(), e.getStackTraceString(), e.getLineNumber(), e.getTypeName(), 'TaskController.getCIFormStatus');
            throw new AuraHandledException('Error getting form status:  ' + e.getMessage());            
        }
    }
    @AuraEnabled
    public static String editCIFormStatus(String matterId, String CIForm) {
        try {
            if (CIForm=='Additional Uploads'){  //since Additional Uploads are not tracked in the tasks
                return 'Success';
            }
            String portalClientTasksId=getClientPortalTaskId(matterid);
            List<Task> listOfCIFormTask = [SELECT Id, WhatId, Subject, ci_form__c, Type, Status FROM Task WHERE (WhatId=:matterId or WhatId=:portalClientTasksId)  AND Type = 'CI Form' AND ci_form__c =:CIForm ];
            if (listOfCIFormTask.size()==0){
                throw new BadIdException('Bad Matter Id submitted:  '+matterId);
            } else {           
                for (Task t : listOfCIFormTask) {
                    t.Status = 'Completed';
                }
                    update listOfCIFormTask;
            }
            return 'Success';
        }catch (Exception e) {
            Utility.createErrorRecord(e.getMessage(), e.getStackTraceString(), e.getLineNumber(), e.getTypeName(), 'TaskController.editCIFormStatus');
            throw new AuraHandledException('Error updating form status:  ' + e.getMessage());              
        }        
    }

    @AuraEnabled
    public static List<Task> getIndividualCIFormStatus(String matterId, String CIForm) {
        try {
            if (CIForm=='Additional Uploads'){  //since Additional Uploads are not tracked in the tasks
                return  new List<Task>();  //as there are no sub tasks associated with Additional Uploads
            }            
            String portalClientTasksId=getClientPortalTaskId(matterid);
            List<Task> listOfCIFormTask = [SELECT WhatId, Subject, ci_form__c, Type, Status FROM Task WHERE (WhatId=:matterId or WhatId=:portalClientTasksId) AND Type = 'CI Form' AND ci_form__c =:CIForm];            
            if (listOfCIFormTask.size()==0){
                throw new BadIdException('Bad Matter Id submitted:  '+matterId);
            }            
            return listOfCIFormTask;
        }catch (Exception e) {
            Utility.createErrorRecord(e.getMessage(), e.getStackTraceString(), e.getLineNumber(), e.getTypeName(), 'TaskController.getIndividualCIFormStatus');
            throw new AuraHandledException('Error getting form status:  ' + e.getMessage());  
        }
    }
}