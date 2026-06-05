public with sharing class ContactTriggerHandler {

    public static void createPersonAccountBefore(List<Contact> newContacts){
        List<Account> accToInsert = new List<Account>();
        Id businessAccRecordType = Schema.SObjectType.Account.getRecordTypeInfosByDeveloperName().get('Business_Account').getRecordTypeId();

        for(Contact con : newContacts){
            // Only create if the contact isn't already attached to an account
            if (con.AccountId == null) {
                Account acc = new Account();
                acc.Name = con.Email;
                acc.RecordTypeId = businessAccRecordType;
                // Map other fields as necessary
                accToInsert.add(acc);
            }
        }
        
        if(!accToInsert.isEmpty()){
            insert accToInsert;
        }
        // Assign Account to Contact
        for(Contact con : newContacts){
            for(Account acc : accToInsert){
                if(acc.Name == con.Email){
                    con.AccountId = acc.Id;
                }
            }
        }        
    }

    public static void createPersonAccountAfter(List<Contact> newContacts){
        Id personAccRT = Schema.SObjectType.Account.getRecordTypeInfosByDeveloperName().get('Web_PC').getRecordTypeId();
        Set<Id> accountIds = new Set<Id>();
        for(Contact con : newContacts) {
            accountIds.add(con.AccountId);
        }
        Account[] accounts = [SELECT Id FROM Account WHERE Id IN :accountIds];
        if(!accounts.isEmpty()){  
            for(Account acc : accounts) {
                acc.RecordTypeId = personAccRT;
            }          
            update accounts; // This changes the account to a Person Account 
            for(Account acc : accounts) {
                for(Contact con : newContacts){
                    if(acc.Id == con.AccountId){
                        acc.Skip_HS_Flow__c = TRUE;
                        acc.FirstName = con.FirstName;
                        acc.LastName = con.LastName;
                        acc.MiddleName = con.MiddleName;
                        acc.PersonEmail = con.Email;
                        acc.Phone = con.Phone;
                        acc.PersonMobilePhone = con.MobilePhone;
                        acc.Web_PC__c = true;
                        acc.PC_Source1__c = 'Website Form';
                        acc.Notes__c = con.Intake_Notes__c;
                        try{
                            acc.Responsible_Office__c = con.Responsible_Office_Intake__c;
                            acc.Type_of_Case_A__c = con.Type_of_Case_Intake__c;
                        }catch(exception e){}
                    }
                }
            }
            update accounts;
        }
    }
}