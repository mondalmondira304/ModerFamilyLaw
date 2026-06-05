global without sharing class PortalUserCreationUtility {
    global class AccountUserInfoClass{
        @InvocableVariable (label='AccountId' required=true) global String AccountId;
        @InvocableVariable (label='User' required=false) global User theUser;
        @InvocableVariable (label='Profile Name' required=true) global String profileName;
    }
    private static String generateUniqueCommunityNickname(String nickname){
        //unhandled exceptions will be handled by createPortalUser
        integer i=1;
        String workingName=nickname;
        List<user> matches= [select id, CommunityNickname from User where CommunityNickname=:workingName ];
        while (matches.size()>0) {
            workingName=nickname.abbreviate( 40-(i.toString().length()) )+i.toString();  // add an index to the nickname making sure the total length does not exceed 40 characters
            i++;
            matches= [select id, CommunityNickname from User where CommunityNickname=:workingName ];
        }
        return Workingname; 
    }
    @InvocableMethod(label='createPortalUser' description='Creates an Experience Cloud Portal User--returns the userid.  If Users is supplied, then that user will be reactivated.  Sharing rules will be created for the user.' category='User')
    global static List<String> createPortalUser(List<AccountUserInfoClass> AccountUserInfo) {
        try {
            String accountId=AccountUserInfo[0].AccountId;
            User theUser=AccountUserInfo[0].theUser;
            String profileName=AccountUserInfo[0].profileName;
            Account person = [select id, FirstName, LastName, PersonEmail, PersonContactId from Account where id=:accountId];
            List<Matters__c> mattersList=[select id, name, Client_Name__c, Opposing_Party_a__c from Matters__c where Client_Name__c=:accountId and status__c='Open'];  //get all open Matters linked to the person account
            Profile prof=[select id, name from profile where name=:profileName];
            String firstName = 'unknown';
            String lastName = 'name';
            if (person.FirstName != null) {
                firstName = person.FirstName;
            }
            if (person.LastName != null) {
                lastName = person.LastName;
            }
            string nickname = firstName.substring(0, 1) + lastName;
            String communityNickname=generateUniqueCommunityNickname(nickname);
            User u;
            User thisUser = [SELECT Id, isActive, IsPortalEnabled, ProfileId FROM User WHERE Id = :UserInfo.getUserId()];            
                 if (theUser!=null){
                    u=theUser;
                    u.isActive=true;
                    u.IsPortalEnabled=true;
                    u.ProfileId=prof.id;
                    system.debug('***The user before the update:  '+u);
                    update u;
                    createTaskToTrackUser(accountId,'This account was reactivated as a Portal User');
                } else {
                    u = new user();
                    u.FirstName = person.FirstName;
                    u.LastName = person.LastName;
                    u.Email = person.PersonEmail;
                    u.Alias = nickname.abbreviate(8); // only 8 characters does not have to be unique
                    u.Username = person.PersonEmail;
                    //u.CommunityNickname = nickname.abbreviate(40);
                    u.CommunityNickname = communityNickname;
                    u.LocaleSidKey = 'en_US';
                    u.TimeZoneSidKey = 'America/Denver ';
                    u.profileId = prof.id;
                    u.LanguageLocaleKey = 'en_US';
                    u.EmailEncodingKey = 'ISO-8859-1';
                    u.ContactId = person.PersonContactId;
                    u.IsActive = true;
                    insert u;
                    createTaskToTrackUser(accountId,'This account was created as a Portal User');
                }
                system.debug('***user created: '+u);
            Map<ID,PermissionSet> permSetsToAssign= new Map<ID,PermissionSet>([Select id from PermissionSet where name in ('CI_Forms_Task','Community_Regular_Permissions','CustomCommunityUserRegular','User_External_Credentials_For_Portal_Users')]) ;                
            List<PermissionSetAssignment> assignmentsToCreate= new List<PermissionSetAssignment>();
            Set<Id> permissionSetsAssigned= new Set<Id>();
            for (PermissionSetAssignment ps:[select permissionSetId from PermissionSetAssignment where assigneeId=:u.id]){
                permissionSetsAssigned.add(ps.permissionSetId);
            }
            for (ID permId:  permSetsToAssign.keySet()){
                if (!permissionSetsAssigned.contains(permId)){
                     assignmentsToCreate.add(new PermissionSetAssignment(AssigneeId=u.id, PermissionSetId=permId));
                }
            }
            if (assignmentsToCreate.size()>0){
                insert assignmentsToCreate;
            }
            Set<Id> mattersIds = new Set<ID>();
            Set<Id> allAccountIds = new Set<Id>();
            for (Matters__c aMatter : Matterslist ){
                mattersIds.add(aMatter.id);
                allAccountIds.add(aMatter.Client_Name__c);
                if (aMatter.Opposing_Party_a__c!=null) {
                    allAccountIds.add(aMatter.Opposing_Party_a__c);
                }
            }
            List<Matters__Share> mattersSharesInserts = new List<Matters__Share>();
            List<AccountShare> accountSharesInserts = new List<AccountShare>();
            return new List<String> {u.Id};
        }
        catch (Exception e) {
            Utility.createErrorRecord(e.getMessage(), e.getStackTraceString(), e.getLineNumber(), e.getTypeName(), 'PortalUserCreationUtility.createPortalUser');
            return null;  // we have to return something...
        }
    }
    @future
    public static void createTaskToTrackUser(String accountId, String subject){
        try {
            Task inserted = new Task();            
            inserted.WhatId=accountId;
            inserted.Subject=subject;
            inserted.Status='Completed';
            inserted.ActivityDate=system.today();
            insert inserted;  
        }   catch (Exception e) {
            Utility.createErrorRecord(e.getMessage(), e.getStackTraceString(), e.getLineNumber(), e.getTypeName(), 'PortalUserCreationUtility.createTaskToTrackUser');
        }
    }

    }