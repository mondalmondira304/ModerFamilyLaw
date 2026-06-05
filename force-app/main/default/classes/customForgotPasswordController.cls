public without sharing class customForgotPasswordController {
    @AuraEnabled
    public static void logPassReset(String emailAddress) {
        if (!String.isBlank(emailAddress)){
            List<User> usrs = new List<User>();
            usrs = [SELECT Id, Account.PersonEmail, AccountId FROM User WHERE Email = :emailAddress];
            for(User usr : usrs){
                EmailMessage newEmailMessage = new EmailMessage();
                newEmailMessage.Status = '3';
                newEmailMessage.MessageDate = DateTime.now();
                newEmailMessage.Subject = 'One Time Passcode Sent';
                newEmailMessage.RelatedToId = usr.AccountId;
                newEmailMessage.ToAddress = usr.Account.PersonEmail;
                insert newEmailMessage; 
            }
        }
    }
}