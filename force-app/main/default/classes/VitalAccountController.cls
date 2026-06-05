public without sharing class VitalAccountController {
    private static Map<String, SObjectType> gdCache {get; set;}
    public class InvalidException extends Exception {}
    public class BadDataException extends Exception {}
    @AuraEnabled
    public static Account updateAccount(Account acc) {
       try{
            if (acc==null){
                throw new invalidException('No account was supplied');
            }
            update acc;
            return acc;
        } catch(exception e) {
            Utility.createFutureErrorRecord(e.getMessage(), e.getStackTraceString(), e.getLineNumber(), e.getTypeName(), 'VitalAccountController.updateAccount');    
            throw new AuraHandledException('Error updateAccount: ' + e.getMessage());
       }
    }    
    @AuraEnabled
    public static Matters__c updateMatter(Matters__c matter) {
       try{
            if (matter==null){
                throw new invalidException('No matter was supplied');
            }
            update matter;
            return matter;
        } catch(exception e) {
            Utility.createFutureErrorRecord(e.getMessage(), e.getStackTraceString(), e.getLineNumber(), e.getTypeName(), 'VitalAccountController.updateMatter');    
            throw new AuraHandledException('Error updateMatter: ' + e.getMessage());
       }
    }
    @AuraEnabled
    public static Matters__c updateMatterDateTime(Matters__c matter) {
       try{
            if (matter==null){
                throw new invalidException('No matter was supplied');
            }        
            DateTime currentDateTime = DateTime.now();
            System.debug('Current DateTime: ' + currentDateTime);
            matter.Opened_in_Portal__c = currentDateTime;
            update matter;
            return matter;
        } catch(exception e) {
            Utility.createFutureErrorRecord(e.getMessage(), e.getStackTraceString(), e.getLineNumber(), e.getTypeName(), 'VitalAccountController.updateMatterDateTime');                
            throw new AuraHandledException('Error updateMatter: ' + e.getMessage());
       }
    }   
    public Class VitalWrapper{
        @AuraEnabled public Account acc;
        @AuraEnabled public Matters__c matter;
    }
    @AuraEnabled(cacheable=true)
    public static Id getCurrentUserAccountId() {
            User u = [SELECT Id, AccountId__c, LastName FROM User WHERE Id =:UserInfo.getUserId()];
            return u?.AccountId__c;
    }    
    @AuraEnabled (cacheable=true)
    public static List<Portal_Video__mdt> getPortalVideos(){
            return Portal_Video__mdt.getAll().values();
    }    
    @AuraEnabled(cacheable=true)
    public static VitalAccountController.VitalWrapper getAccountDetails() {      
     VitalAccountController.VitalWrapper retVal = new VitalAccountController.VitalWrapper();
       try{
           String accountId = getCurrentUserAccountId();
           System.debug('accountId: '+accountId);
           retVal.acc = [SELECT Id, Salutation, FirstName,Spouse_Text__c,MiddleName,LastName,Gender__c,Race__c,State_A__c,PersonEmail,Phone,PersonMobilePhone,PersonMailingAddress,PersonMailingStreet, 
                    PersonMailingCity, PersonMailingState, PersonMailingPostalCode,PersonMailingCountry,County_of_Residence__c , Length_of_Residence__c,
                    Birthdate__c,Drivers_License__c,Drivers_License_State__c,Social_Security_Number__c,Military_Branch__c,Adults_in_Household__c,
                    of_Children_of_this_Relationship__c,Military_Rank__c,Military_Pay_Grade__c,Currently_Service_Connected__c,Length_of_Relationship__c,Level_of_Education__c,Degree_Obtained__c,
                    Professional_Licenses__c,Years_of_college__c,Years_of_Graduate_School__c,Facebook__c,Instagram__c,LinkedIn__c,Twitter__c,Pinterest__c,Vitals_Certified__c,
                    Birth_City__c, Birth_State__c, Birth_Country__c, Current_Employer__c, Job_Title__c, Photo_URL__c, Credit_Decision__c
                    FROM Account WHERE ( Id =:accountId ) LIMIT 1];           
                    System.debug('Fetched Account: ' + retVal.acc);                
          List<Matters__c> matters = [Select Id, Date_of_Marriage__c, Marriage_City__c, Marriage_State__c, Marriage_Country__c, Date_of_Separation__c, Name_Change__c, New_Restored_Name__c,Health_Ins_Provider_Children__c,Flex_Cafeteria_Plan_Children__c,Uncovered_Costs__c,Health_Policy_Number_Children__c,Children_s_Portion_of_HI_Premium__c,Life_Insurance_Paid_by_Employer_OP__c from Matters__c where Client_Name__c =: accountId limit 1];        
          if (matters.size()>0){
            retVal.matter=matters[0];
          } else {
            retVal.matter=null;
          }
          return retVal; 
       } catch(exception e) {
            Utility.createFutureErrorRecord(e.getMessage(), e.getStackTraceString(), e.getLineNumber(), e.getTypeName(), 'VitalAccountController.getAccountDetails');            
            throw new AuraHandledException('Error getAccountDetails: ' + e.getMessage());
       }
    }  
    @AuraEnabled(cacheable=true)
    public static list<Matters__c> getOpposingParties() {
       try{
            Id accountId = getCurrentUserAccountId();
            return [SELECT Id, Opposing_Party_a__r.Id, Opposing_Party_a__r.Name, Opposing_Party_a__r.Salutation,Opposing_Party_a__r.Spouse_Text__c,Opposing_Party_a__r.FirstName,Opposing_Party_a__r.MiddleName,Opposing_Party_a__r.LastName,Opposing_Party_a__r.Gender__c,Opposing_Party_a__r.Race__c,Opposing_Party_a__r.PersonEmail,Opposing_Party_a__r.Phone,Opposing_Party_a__r.PersonMobilePhone,Opposing_Party_a__r.PersonMailingAddress,Opposing_Party_a__r.Length_of_Residence__c,
            Opposing_Party_a__r.Birthdate__c,Opposing_Party_a__r.Drivers_License__c,Opposing_Party_a__r.Drivers_License_State__c,Opposing_Party_a__r.Social_Security_Number__c,Opposing_Party_a__r.Military_Branch__c,Opposing_Party_a__r.Adults_in_Household__c,
            Opposing_Party_a__r.of_Children_of_this_Relationship__c,Opposing_Party_a__r.Military_Rank__c,Opposing_Party_a__r.Military_Pay_Grade__c,Opposing_Party_a__r.Currently_Service_Connected__c,Opposing_Party_a__r.Length_of_Relationship__c,Opposing_Party_a__r.Level_of_Education__c,Opposing_Party_a__r.Degree_Obtained__c,
            Opposing_Party_a__r.Professional_Licenses__c,Opposing_Party_a__r.Years_of_college__c,Opposing_Party_a__r.Years_of_Graduate_School__c,Opposing_Party_a__r.Facebook__c,Opposing_Party_a__r.Instagram__c,Opposing_Party_a__r.LinkedIn__c,Opposing_Party_a__r.Twitter__c,Opposing_Party_a__r.Pinterest__c,
            Opposing_Party_a__r.Vitals_Certified__c,Opposing_Party_a__r.Height__c,Opposing_Party_a__r.Hair_Color__c,Opposing_Party_a__r.Vehicle__c,Opposing_Party_a__r.Best_Location__c,Opposing_Party_a__r.Days_Time_for_Best_Location__c,Opposing_Party_a__r.Alternate_Location_for_Service__c,Opposing_Party_a__r.Day_Time_for_Alternate_Location__c,Opposing_Party_a__r.Identifying_Features__c,Opposing_Party_a__r.Pronoun_He_She_They__c 
            FROM Matters__c WHERE Client_Name__r.Id = :accountId AND Status__c='Open' LIMIT 1 ];
        } catch(exception e) {
            Utility.createFutureErrorRecord(e.getMessage(), e.getStackTraceString(), e.getLineNumber(), e.getTypeName(), 'VitalAccountController.getOpposingParties');                
            throw new AuraHandledException('Error getOpposingParties: ' + e.getMessage());
       }
    }
    @AuraEnabled(cacheable=true)
    public static list<Matters__c> getOpposingPartiesForSelectdMatter(String matterId) {
       try{
            if (matterId==null){
                throw new invalidException('No matter was supplied');
            }   
            Id accountId = getCurrentUserAccountId();
            return [SELECT Id, Opposing_Party_a__r.Id, Opposing_Party_a__r.Name, Opposing_Party_a__r.Salutation,Opposing_Party_a__r.Spouse_Text__c,Opposing_Party_a__r.Weight__c,Opposing_Party_a__r.FirstName,Opposing_Party_a__r.MiddleName,Opposing_Party_a__r.LastName,Opposing_Party_a__r.Gender__c,Opposing_Party_a__r.Race__c,Opposing_Party_a__r.PersonEmail,Opposing_Party_a__r.Phone,Opposing_Party_a__r.PersonMobilePhone,Opposing_Party_a__r.PersonMailingAddress,Opposing_Party_a__r.Length_of_Residence__c,
            Opposing_Party_a__r.Birthdate__c,Opposing_Party_a__r.Drivers_License__c,Opposing_Party_a__r.Drivers_License_State__c,Opposing_Party_a__r.Social_Security_Number__c,Opposing_Party_a__r.Military_Branch__c,Opposing_Party_a__r.Adults_in_Household__c,
            Opposing_Party_a__r.of_Children_of_this_Relationship__c,Opposing_Party_a__r.Military_Rank__c,Opposing_Party_a__r.Military_Pay_Grade__c,Opposing_Party_a__r.Currently_Service_Connected__c,Opposing_Party_a__r.Length_of_Relationship__c,Opposing_Party_a__r.Level_of_Education__c,Opposing_Party_a__r.Degree_Obtained__c,
            Opposing_Party_a__r.Professional_Licenses__c,Opposing_Party_a__r.Years_of_college__c,Opposing_Party_a__r.Years_of_Graduate_School__c,Opposing_Party_a__r.Facebook__c,Opposing_Party_a__r.Instagram__c,Opposing_Party_a__r.LinkedIn__c,Opposing_Party_a__r.Twitter__c,Opposing_Party_a__r.Pinterest__c,
            Opposing_Party_a__r.Vitals_Certified__c,Opposing_Party_a__r.Height__c,Opposing_Party_a__r.Hair_Color__c,Opposing_Party_a__r.Vehicle__c,Opposing_Party_a__r.Best_Location__c,Opposing_Party_a__r.Days_Time_for_Best_Location__c,Opposing_Party_a__r.Alternate_Location_for_Service__c,Opposing_Party_a__r.Day_Time_for_Alternate_Location__c,Opposing_Party_a__r.Identifying_Features__c,Opposing_Party_a__r.Pronoun_He_She_They__c 
            FROM Matters__c WHERE Client_Name__r.Id = :accountId AND Status__c='Open' AND Id = :matterId LIMIT 1 ];
        } catch(exception e) {
            Utility.createFutureErrorRecord(e.getMessage(), e.getStackTraceString(), e.getLineNumber(), e.getTypeName(), 'VitalAccountController.getOpposingPartiesForSelectdMatter');                
            throw new AuraHandledException('Error getOpposingParties: ' + e.getMessage());
       }
    }
    /*@AuraEnabled
    public static list<Account> getAllAccounts() {
       try{
            return [SELECT Id, Name FROM Account ];
        } catch(exception e) {
            Utility.createFutureErrorRecord(e.getMessage(), e.getStackTraceString(), e.getLineNumber(), e.getTypeName(), 'VitalAccountController.getAllAccounts');                
            throw new AuraHandledException('Error accountList: ' + e.getMessage());
       }
    }
    @AuraEnabled(cacheable=true)
    public static List<ContentDocumentLink> getRelatedFiles(Id recordId) {   
        Id accountId = getCurrentUserAccountId();           
        return [
            SELECT ContentDocumentId, ContentDocument.Title, ContentDocument.FileType,
                   ContentDocument.LatestPublishedVersionId
            FROM ContentDocumentLink
            WHERE LinkedEntityId = : accountId
        ];
    }*/
    @AuraEnabled(cacheable=true)
    public static Account getOpposingPartiesDetails(Id accountId) {
        return [SELECT Id, FirstName,Spouse_Text__c,MiddleName,LastName,Salutation,Gender__c,In_Military__c,Birth_City__c,Birth_State__c,Birth_Country__c,Race__c,PersonEmail,Phone,PersonMobilePhone,PersonMailingAddress,PersonMailingStreet, PersonMailingCity, PersonMailingState, PersonMailingPostalCode,PersonMailingCountry,County_of_Residence__c , Length_of_Residence__c,
                    Birthdate__c,Drivers_License__c,Drivers_License_State__c,Social_Security_Number__c,Military_Branch__c,Adults_in_Household__c,
                    of_Children_of_this_Relationship__c,Military_Rank__c,Military_Pay_Grade__c,Currently_Service_Connected__c,Length_of_Relationship__c,Level_of_Education__c,Degree_Obtained__c,
                    Professional_Licenses__c,Years_of_college__c,Years_of_Graduate_School__c,Facebook__c,Instagram__c,LinkedIn__c,Twitter__c,Pinterest__c,
                    Vitals_Certified__c,Height__c,Hair_Color__c,Vehicle__c,Best_Location__c,Days_Time_for_Best_Location__c,Alternate_Location_for_Service__c,Day_Time_for_Alternate_Location__c,Identifying_Features__c,Pronoun_He_She_They__c FROM Account WHERE Id = :accountId LIMIT 1];
    }
    @AuraEnabled
    public static string updateRecordDetail(String recordDetail, String objectApiName) {       
        try{
            // Get the SObject type dynamically
            SObjectType sObjectType = Schema.getGlobalDescribe().get(objectApiName);
            // Create a new instance of the SObject
            SObject sRecord = sObjectType.newSObject();
            // Deserialize the JSON string into a Map
            Map<String, Object> jsonMap = (Map<String, Object>) JSON.deserializeUntyped(recordDetail);
            // Get the SObject's field mapnew
            Map<String, Schema.SObjectField> fieldMap = sObjectType.getDescribe().fields.getMap();    
            // Loop through the JSON map and populate the SObject fields
            for (String fieldName : jsonMap.keySet()) {
                // Get the field describe result to check field type
                if(fieldMap.containsKey(fieldName)) {
                    Schema.DisplayType fieldType = fieldMap.get(fieldName).getDescribe().getType();
                    String label= fieldMap.get(fieldName).getDescribe().getLabel();  //String
                    // Handle different field types
                    Object fieldValue = jsonMap.get(fieldName);
                    if(fieldValue != null) {
                        // Perform type conversion based on the field's data type
                        if (fieldType == Schema.DisplayType.Currency || fieldType == Schema.DisplayType.Double || fieldType == Schema.DisplayType.Percent) {
                            // Convert to Decimal
                            try {
                                sRecord.put(fieldName, Decimal.valueOf(String.valueOf(fieldValue)));
                            } catch (Exception e){
                                throw new BadDataException(fieldValue+' is supposed to be a decimal value but is not.  Please correct the data for '+label+' and try again '); // bubbles up to the 
                            }
                        } else if (fieldType == Schema.DisplayType.Integer) {
                            // Convert to Integer
                            try {                            
                                sRecord.put(fieldName, Integer.valueOf(String.valueOf(fieldValue)));
                            } catch (Exception e){
                                throw new BadDataException(fieldValue+' is supposed to be an integer value but is not.  Please correct the data for '+label+' and try again '); // bubbles up to the 
                            }
                        } else if (fieldType == Schema.DisplayType.Date) {
                            // Convert to Date
                            try {
                                sRecord.put(fieldName, Date.valueOf(String.valueOf(fieldValue)));
                            } catch (Exception e){
                                throw new BadDataException(fieldValue+' is supposed to be a date value but is not.  Please correct the data for '+label+' and try again '); // bubbles up to the 
                            }
                        } else if (fieldType == Schema.DisplayType.DateTime) {
                            // Convert to DateTime
                            try {
                                sRecord.put(fieldName, Datetime.valueOf(String.valueOf(fieldValue)));  
                            } catch (Exception e){
                                throw new BadDataException(fieldValue+' is supposed to be a date time value but is not.  Please correct the data for '+label+' and try again '); // bubbles up to the 
                            }
                        } else if (fieldType == Schema.DisplayType.Boolean) {
                            // Convert to Boolean
                            try {
                                sRecord.put(fieldName, Boolean.valueOf(String.valueOf(fieldValue)));
                            } catch (Exception e){
                                throw new BadDataException(fieldValue+' is supposed to be a true/false value but is not.  Please correct the data for '+label+' and try again '); // bubbles up to the 
                            }
                        } else {
                            // Default case, handle as String or other types
                            try {
                                sRecord.put(fieldName, String.valueOf(fieldValue));
                            } catch (Exception e){
                                throw new BadDataException(fieldValue+' is supposed to be a strin value but is not.  Please correct the data for '+label+' and try again '); // bubbles up to the 
                            }
                        }
                    }
                } 
            }           
            // update sRecord;
            if (sRecord.get('Id') == null) {
                insert sRecord;
            } else {
                update sRecord;
            }
            return string.valueOf(sRecord.get('Id'));
        } catch (Exception e) {
            Utility.createFutureErrorRecord(e.getMessage(), e.getStackTraceString(), e.getLineNumber(), e.getTypeName(), 'VitalAccountController.updateRecordDetail');    
            throw new AuraHandledException('Error processing record: ' + e.getMessage());
        }
    }
    @AuraEnabled(cacheable=true)
    public static String getObjectNameById(String recordId) {
        try {
            return String.valueOf(Id.valueOf(recordId).getSObjectType().getDescribe().getName());
        } catch (Exception e) {
            Utility.createFutureErrorRecord(e.getMessage(), e.getStackTraceString(), e.getLineNumber(), e.getTypeName(), 'VitalAccountController.getObjectNameById');    
            throw new AuraHandledException('Error getObjectNameById: ' + e.getMessage());            
        }
    }
    @AuraEnabled
    public static Employment__c gettingEmployeePhone(String recordDetail) {
        try {
            Employment__c employeePhone = [SELECT Id, Employer_Phone__c,Self_Employed_at_this_Job__c FROM Employment__c WHERE Id = :recordDetail LIMIT 1];
            System.debug('employeePhone'+employeePhone.Employer_Phone__c);
            return employeePhone;
        } catch (Exception e) {
            Utility.createFutureErrorRecord(e.getMessage(), e.getStackTraceString(), e.getLineNumber(), e.getTypeName(), 'VitalAccountController.gettingEmployeePhone');    
            throw new AuraHandledException('Error gettingEmployeePhone: ' + e.getMessage());
        }
    }
    /*
    @AuraEnabled
    public static Map<String, Object> updateAccountAndMatter(Account acc, Matters__c matter) {
        update acc;
        update matter;       
        Map<String, Object> result = new Map<String, Object>();
        result.put('account', acc);
        result.put('matter', matter);
        return result;
    }*/
}