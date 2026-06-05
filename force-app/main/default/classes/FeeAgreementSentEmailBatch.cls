public class FeeAgreementSentEmailBatch implements database.batchable<sobject>,schedulable{
    public database.queryLocator start(Database.batchableContext bc){
        Date thirtyDaysBeforeFilter = system.today()-30;
        Date todayDate = system.today();
        Date threeDaysBeforeFilter = system.today()-3;
        string statusFilter = 'Fee Agreement Pending';
        string query = 'select Id,ICI_Attorney_Email_A__c,ICI_Attorney_A__c,ICI_Attorney_A__r.Name,Name,LastName,Pending_Fee_Last_Email_Sent_Date__c,FirstName,Phone_Attorney_A__c,Phone_Attorney_A__r.name,Consultation_Status__c,Fee_Agreement_Sent__c from account ';
        if(!test.isRunningTest()){
            query += ' where Fee_Agreement_Sent__c >= :thirtyDaysBeforeFilter ';
            query += ' and Consultation_Status__c= :statusFilter and ICI_Attorney_Email_A__c != null';
            query += ' and (Fee_Agreement_Sent__c = :threeDaysBeforeFilter or (Pending_Fee_Last_Email_Sent_Date__c != null and Pending_Fee_Last_Email_Sent_Date__c = :threeDaysBeforeFilter))';
        }
        return database.getQueryLocator(query);
    }
    
    public void execute(Database.batchableContext bc, List<account> accounts){
        
        List<Messaging.SingleEmailMessage> emailsNeedToSend = new List<Messaging.SingleEmailMessage>();
        List<account> accountsNeedToUpdate = new List<account>();
        for(account acc : accounts){
            string emailBody = 'Hello '+acc.ICI_Attorney_A__r.Name +',<br/><br/>';
            emailBody += 'Please follow up with the Potential Client '+acc.Name +' as the Fee Agreement has not been signed.<br/>';           
            
            emailBody += '<br/>You may view your Potential Client here :';            
            string orgUrl = URL.getOrgDomainURL().toExternalForm()+'/lightning/r/Account/'+acc.Id+'/view';
            emailBody += ' <a href="'+orgUrl+'">'+acc.Name+'</a>.<br/><br/>';
            emailBody += 'Remember to update the status in the Attorney Follow Up section.<br/><br/>';
            emailBody += 'Additional reminders will be sent every three days until the Fee Agreement is signed or canceled. The Fee Agreement will expire at 30 days.';
            emailBody += '<p>Thank you.</p>';
            
            Messaging.SingleEmailMessage email = new Messaging.SingleEmailMessage();
            String[] sendingTo = new String[]{acc.ICI_Attorney_Email_A__c};
                email.setToAddresses(sendingTo); 
            
            email.setSubject('Fee Agreement Reminder');
            email.setHtmlBody(emailBody);
            emailsNeedToSend.add(email);      
            
            account accnt = new account();
            accnt.Id = acc.Id;
            accnt.Pending_Fee_Last_Email_Sent_Date__c = system.today();
            accountsNeedToUpdate.add(accnt);
        }
        Messaging.sendEmail(emailsNeedToSend);
        update accountsNeedToUpdate;
    }
    
    public void finish(Database.batchableContext bc){
        
    }
    
    public void execute(schedulableContext sc){
        database.executeBatch( new FeeAgreementSentEmailBatch(),100);
    }
    
}