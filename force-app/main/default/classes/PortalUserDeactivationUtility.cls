global without sharing class PortalUserDeactivationUtility {
    @InvocableMethod(label='DeactivePortalUser' description='If the user is linked to a client account but that client account does not have an active matter, deactivate the user. Returns deactivated Users.' category='User')
    global static List<User>  deactivatePortaUser() {
        try {
            set<Id> activePortalUserIds=new set<Id>();
            for (User u: [select id, accountId__c from user where isactive=true and profile.name='Customer Community User'] ){
                activePortalUserIds.add(u.accountId__c);
            }
            List <User> usersToDeactivate = new List <user>();
            integer previousCount;
            integer currentCount;
            List <Account> accts=[select name, id, send_credit_request__c, recordtype.name, (select id, name, profile.name, isactive from users where isactive=true and profile.name='Customer Community User'),
                (select id, name, status__c from matters__r where status__c!='Closed' and status__c!='Refund Due' and status__c!='3rd party collection' and status__c!='Internal Collections'   ) //
                from account 
                where id in (select client_name__c from matters__c ) and id in :activePortalUserIds and RecordType.Name='Client'];  //since we only want client accounts and accounts linked to Portal Users to start with
            Map<Id,Account> acctsWithoutOpenMatters= new Map<Id,Account>();
            for (Account acct: accts){
                if (acct.Users.size()>0)    {  // if the account is linked to a Portal user
                    acctsWithoutOpenMatters.put(acct.Id, acct);  //assume the account does not have an open matter
                    for (Matters__c activeMatters: acct.matters__r){
                        acctsWithoutOpenMatters.remove(acct.Id);  //found a matter that that we should keep open
                    }
                }
            }
            Integer numberWithSendCreditRequest=0;
            for (Account acct : acctsWithoutOpenMatters.values()){
                if (acct.send_credit_request__c=true){
                    numberWithSendCreditRequest++;
                    system.debug('*** Accts with only CLOSED Matters and Portal users to deactivate:  '+acct);
                }
                usersToDeactivate.add(acct.Users);
            }            
            system.debug('*** Number of Client users to deactivate:  '+usersToDeactivate.size());            
            previousCount=usersToDeactivate.size();                         
            /* get PC accounts that have completed Simple Start AND are not going through the new fee agreement process -- PC accounts by definition do not have matters
            unfortunately, this was deactivating users after intake made the mistake of not checking the allow_fee_agreement__c checkbox */
            accts=[select name, id, send_credit_request__c, Credit_Check_Complete__c,  Credit_Report_Link__c, recordtype.name, 
                (select id, name, profile.name, isactive, LastLoginDate, lastmodifieddate from users where isactive=true and profile.name='Customer Community User')
                from account 
                where  RecordType.Name='Potential Client' and id in :activePortalUserIds and (Credit_Check_Complete__c=true and allow_fee_agreement__c=false  )];                  
            DateTime latestDate ;                
            for (Account acct:accts)    {
                latestDate =getLatestDate(acct.Users[0]);
                if (latestDate < system.Date.today().addDays(-10) ) { //basically we are giving 10 days for intake to set allow_fee_agreement__c = true
                    usersToDeactivate.add(acct.Users);                        
                }
            } 
            currentCount=usersToDeactivate.size()-previousCount;
            system.debug('*** Number of Simple Start users to deactivate:  '+currentCount);
            previousCount=usersToDeactivate.size();
            /* give a PC account 45 days after the PC account was created or since their last successful login to convert to a client -- this is simpler logic */
            /* PC account is provisioned as a Portal user after being put through the Simple Start or FA automation processes */
            accts=[select name, id, send_credit_request__c, Credit_Check_Complete__c,  Credit_Report_Link__c, recordtype.name, 
                (select id, name, profile.name, isactive, LastLoginDate, lastmodifieddate from users where isactive=true and profile.name='Customer Community User')
                from account 
                where  RecordType.Name='Potential Client' and id in :activePortalUserIds ];                  
            //DateTime latestDate ;
            for (Account acct:accts)    {
                if (acct.Users.size()>0)    { // if the account is linked to a Portal user
                    latestDate =getLatestDate(acct.Users[0]);
                    if (latestDate < system.Date.today().addDays(-45) ) {
                        usersToDeactivate.add(acct.Users);                        
                    }
                }
            }
            currentCount=usersToDeactivate.size()-previousCount;
            system.debug('*** Number of Portal users that have not converted to a client more than 45 days since being created or since their last login or since the last user record update:  '+currentCount);            
            for (User u: usersToDeactivate){
                u.isactive=false;
            }
            update usersToDeactivate ;
            return usersToDeactivate ;            
        }
        catch (Exception e) {
            Utility.createErrorRecord(e.getMessage(), e.getStackTraceString(), e.getLineNumber(), e.getTypeName(), 'PortalUserDeactivationUtility.deactivatePortaUser');
            return null;  // we have to return something...
        }
    }
    static DateTime getLatestDate(User userIn){
        if (userIn.LastLoginDate!=null && userIn.LastLoginDate>userIn.LastModifiedDate){
            return userIn.LastLoginDate;
        }
        return userIn.LastModifiedDate;  //will account for when the user was created or reactivated        
    }
}