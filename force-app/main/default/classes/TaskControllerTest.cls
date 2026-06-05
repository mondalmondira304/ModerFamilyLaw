@isTest
public class TaskControllerTest {
    @testSetup
    static void setupTestData() {
        Account acc = new Account(FirstName='Test', LastName='User', personemail='test@test.com');
        insert acc;
        MFL_Office__c mflOffice = new MFL_Office__c(Name = 'Test');
        insert mflOffice;       
        Matters__c matter = new Matters__c(Name='Test Matter', Client_Name__c=acc.Id, MFL_Office__c = mflOffice.Id, Hire_date__c=System.date.today());
        insert matter;      
        Client_Portal_Tasks__c cpt =[select id from Client_Portal_Tasks__c where Matter__c=:matter.Id limit 1];        
        Task t1 = new Task(WhatId = cpt.Id, ci_form__c = 'Form 1', Type = 'CI Form', Status = 'Open' );
        insert t1;        
        /*Task t1 = new Task(WhatId = matter.Id, ci_form__c = 'Form 1', Type = 'CI Form', Status = 'Open' );
        insert t1;*/
    }
    @isTest
    static void testGetCIFormStatus() {
        Matters__c matter=[select id from matters__c limit 1];
        List<Task> tasks = TaskController.getCIFormStatus(matter.Id);    
        System.assert(tasks.size()>0);
        System.assertEquals('CI Form', tasks[0].Type);
    }
    @isTest
    static void testEditCIFormStatus() {
        Matters__c matter=[select id from matters__c limit 1];
        String result = TaskController.editCIFormStatus(matter.Id, 'Form 1');
        System.assertEquals('Success', result);
        // Verify task status is updated
        List<Task> updatedTasks = [SELECT Status, CompletedDateTime FROM Task where ci_form__c='Form 1'];
        for (Task t:updatedTasks)
        {   System.assertEquals('Completed', t.Status);
            System.assertEquals(date.today(), t.CompletedDateTime.date());       
        }

    }
    @isTest
    static void testGetIndividualCIFormStatus() {
        Matters__c matter=[select id from matters__c limit 1];
        List<Task> result = TaskController.getIndividualCIFormStatus(matter.Id, 'Form 1');
        System.assertEquals(1, result.size());
    }    
    @isTest
    static void TooManyClientPortalTasksException() {
        // Create a test Account or custom object that is the parent of Task (Matter)
        try {
            Matters__c matter=[select id from matters__c limit 1];
            Client_Portal_Tasks__c cpt =new Client_Portal_Tasks__c(Name='One too many', Matter__c=matter.Id);
            insert cpt;
            List<Task> tasks2 = TaskController.getIndividualCIFormStatus(matter.Id, 'Form 1');  //too many client_portal_tasks__c records on the matter
        } catch (Exception e) {        
            List<ErrorLog__c> errors=[select id from errorLog__c];
            System.assertEquals(1,errors.size());
        }
    }    
    @isTest
    static void GetCIFormStatusException() {
        // Create a test Account or custom object that is the parent of Task (Matter)
        try {
            List<Task> tasks2 = TaskController.getCIFormStatus('001');  //invalid id
        } catch (Exception e) {        
            List<ErrorLog__c> errors=[select id from errorLog__c];
            System.assertEquals(1,errors.size());
        }
    }
    @isTest
    static void EditCIFormStatusException() {
        try{
            String error = TaskController.editCIFormStatus('001', 'Form 1');    //invalid id                    
        } catch (Exception e) {
            List<ErrorLog__c> errors=[select id from errorLog__c];
            System.assertEquals(1,errors.size());        
        }
    }
    @isTest
    static void GetIndividualCIFormStatusException() {
        try {
            List<Task> error = TaskController.getIndividualCIFormStatus('001', 'Form 1');   //invalid id     
        }  catch (Exception e) {
            List<ErrorLog__c> errors=[select id from errorLog__c];
            System.assertEquals(1,errors.size());
        }
    }
}