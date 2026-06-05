public without sharing class AccountUtils{
    public class emailRequest {
        @InvocableVariable(label='User Record' required=true)
        public user theUser;
        @InvocableVariable(label='Email Template Developer Name' required=true)
        public String emailTemplateDeveloperName;
    }  
    @InvocableMethod(label='Email Actions' description='Pass in the user and the email template developer name' category='User')
    public static void updateUserList(List<emailRequest> emailRequests) {
        Map<Id,Id> conEmailTemplateMap = new Map<Id,String>();  //contact ids and the email template ids        
        Map<String,Id> emailTemplateToId = new Map<String,Id>();
        for(emailRequest req : emailRequests){
            emailTemplateToId.put(req.emailTemplateDeveloperName, null);
        }
        List <EmailTemplate> emailtemplates=[SELECT DeveloperName,Id FROM EmailTemplate WHERE DeveloperName = :emailTemplateToId.keyset()];
        for (EmailTemplate e: emailtemplates){
            emailTemplateToId.put(e.DeveloperName, e.Id);
        }
        for(emailRequest req : emailRequests){
            conEmailTemplateMap.put(req.theUser.ContactId,emailTemplateToId.get(req.emailTemplateDeveloperName) );
        }        
        if(!conEmailTemplateMap.isEmpty()){
            createEmailMessageRecords(conEmailTemplateMap);
        }
    }    
    @future
    public static void createEmailMessageRecords(Map<Id,String> conEmailTemplateMap){
        //Since we also need the accountId associated with the contact but we can't pass a map containing a custom class to a future method, build the map inside of the future method
        Map<Id,Contact> ContactIdToContactMap= new Map<Id,Contact>([select id,AccountId from Contact where Id in :conEmailTemplateMap.keySet()]);   
        try {
            OrgWideEmailAddress[] owea = [select Id from OrgWideEmailAddress where Address = 'reception@modernfamilylaw.com'];
            if(!conEmailTemplateMap.isEmpty()){
                for(Id conId : conEmailTemplateMap.keyset()){
                    Messaging.SingleEmailMessage mail = new Messaging.SingleEmailMessage();
                    mail.setOrgWideEmailAddressId(owea.get(0).Id);
                    mail.setTemplateId(conEmailTemplateMap.get(conId));  //will retrieve the email template id
                    mail.setTargetObjectId(conId); 
                    mail.setWhatId(ContactIdToContactMap.get(conId).AccountId);
                    mail.setSaveAsActivity(true);
                    Messaging.sendEmail(new Messaging.SingleEmailMessage[] { mail });
                }
            }
        } catch(Exception e) {
            Utility.createErrorRecord(e.getMessage(), e.getStackTraceString(), e.getLineNumber(), e.getTypeName(), 'AccountUtils.createEmailMessageRecords');
        }
    }
}