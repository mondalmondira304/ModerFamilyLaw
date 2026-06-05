public without sharing class ChildrenController {
    public class invalidObjectException extends Exception {}
    @AuraEnabled(cacheable=true)
    public static List<Children__c> getChildrenListByMatter(String matterId) {
        try {
            if (matterId==null){
                return getChildrenList();
            }
            system.debug('****MatterId:  ' + MatterId);            
            if (MatterId==null) { return new List<Children__c>(); }
            list< Children__c > childrens = [SELECT Id, Name, Name__c,Child_Resides_With__c,Child_Age__c, Gender__c, Parent_1__c,Parent_1__r.Name, Parent_2__c,Parent_2__r.Name 
                FROM Children__c 
                WHERE Matter_ID__c=:matterId]; //want only child related to the matter
            system.debug(' ======= ' + childrens);
            return childrens;
        } catch(Exception e) {
            Utility.createErrorRecord(e.getMessage(), e.getStackTraceString(), e.getLineNumber(), e.getTypeName(), 'ChildrenController.getChildrenListByMatter');            
            throw new AuraHandledException('Error in getChildrenList: ' + e.getMessage());
        }
    } 
    @AuraEnabled(cacheable=true)
    public static List<Children__c> getChildrenList() {
        try {
            Id accountId = getCurrentUserAccountId();
            System.debug(' ===== Account ID======= ' + accountId);
            list< Children__c > childrens = [SELECT Id, Name, Name__c,Child_Resides_With__c,Child_Age__c, Gender__c, Parent_1__c,Parent_1__r.Name, Parent_2__c,Parent_2__r.Name 
                FROM Children__c 
                WHERE Parent_1__c =: accountId OR Parent_2__c =: accountId];
            system.debug(' ======= ' + childrens);
            return childrens;
        } catch(Exception e) {
            Utility.createErrorRecord(e.getMessage(), e.getStackTraceString(), e.getLineNumber(), e.getTypeName(), 'ChildrenController.getChildrenList');    
            throw new AuraHandledException('Error in getChildrenList: ' + e.getMessage());
        }
    } 
    @AuraEnabled(cacheable=true)
    public static Id getCurrentUserAccountId() {
            User user = [SELECT Id, AccountId__c, Name FROM User WHERE Id =: UserInfo.getUserId() ];
            System.debug('User Info: ' + user);
            return user.AccountId__c;
    }
    @AuraEnabled
    public static Children__c  getChildData(Id selectedRecordId){
        try {
            return [SELECT Name, Street__c, Gender__c, Time_in_Jurisdiction__c, City__c, State__c, Social_Security_Number__c, Date_of_Birth__c, Race__c, Parent_1__c, Parent_2__c, If_Other__c, Child_Resides_With__c, Dependent_Child_monthly_income_source__c, Dependent_Children_s_monthly_gross__c, Birth_City__c, Birth_State__c, Birth_Country__c, Percent_of_time_with_Client__c, Percent_of_time_with_Other__c, Travel_expenses_for_visitation_monthly__c, Tribe__c, Member_Number__c, School_Enrolled__c, School_Address__c, Educational_or_other_special_needs_month__c, School_Grade__c, Teacher__c, Notes_on_Education_Schooling__c, Childcare_Provider__c, Childcare_Address__c, Childcare_Schedule__c, Gross_Monthly_Childcare_Cost__c, Who_Pays__c, Parent_1_Text__c, Parent_2_Text__c FROM Children__c WHERE Id =:selectedRecordId LIMIT 1];
        } catch (Exception e) {
            Utility.createErrorRecord(e.getMessage(), e.getStackTraceString(), e.getLineNumber(), e.getTypeName(), 'ChildrenController.getChildData');   
            throw new AuraHandledException(e.getMessage());
        }
    }

    @AuraEnabled
    public static Children__c updateChildData(Children__c childd) {
       try{
            System.debug(childd);            
            update childd;
            return childd;
        } catch(exception e) {
           Utility.createErrorRecord(e.getMessage(), e.getStackTraceString(), e.getLineNumber(), e.getTypeName(), 'ChildrenController.updateChildData');   
           throw new AuraHandledException('Error updateChild: ' + e.getMessage());
       }
    }
    @AuraEnabled
    public static Children__c addChildData(Children__c childd) {
       system.debug( ' ************************* ' );
       try{
            System.debug(childd);
            insert childd;
            return childd;
        } catch(exception e) {
           Utility.createErrorRecord(e.getMessage(), e.getStackTraceString(), e.getLineNumber(), e.getTypeName(), 'ChildrenController.addChildData');   
           throw new AuraHandledException('Error addChild: ' + e.getMessage());
       }
    }
    @AuraEnabled
    public static List<Activities__c> getActivitiesList(String childId) {
        try {
            Id accountId = getCurrentUserAccountId();
            System.debug(' ===== Account ID======= ' + accountId);
            list< Activities__c > activitiesList = [SELECT Id, Name, Weekly_Schedule__c, Activity_Type__c, Activity_Provider__c, Who_Pays_for_Activity__c, Who_Pays_for_Activity__r.Name, Matter__c, Cost__c, Who_Pays_for_Activity_Text__c 
            FROM Activities__c 
            WHERE Child_Name__c =: childId];
            
            system.debug(' ======= ' + activitiesList);
            return activitiesList;
        } catch(Exception e) {
            Utility.createErrorRecord(e.getMessage(), e.getStackTraceString(), e.getLineNumber(), e.getTypeName(), 'ChildrenController.getActivitiesList');  
            throw new AuraHandledException('Error in getActivitiesList: ' + e.getMessage());
        }
    }
    @AuraEnabled
    public static List<Medical_Providers__c> getMedicalProvidersList(String childId) {
        try {
            Id accountId = getCurrentUserAccountId();
            System.debug(' ===== Account ID======= ' + accountId);
            list< Medical_Providers__c > providersList = [SELECT Id, Name, Medical_Clinic_s_Name__c, Type_of_Provider__c
            FROM Medical_Providers__c 
            WHERE Child_Name__c =: childId];
            system.debug(' ======= ' + providersList);
            return providersList;
        } catch(Exception e) {
            Utility.createErrorRecord(e.getMessage(), e.getStackTraceString(), e.getLineNumber(), e.getTypeName(), 'ChildrenController.getMedicalProvidersList');  
            throw new AuraHandledException('Error in getMedicalProvidersList: ' + e.getMessage());
        }
    }
    @AuraEnabled
    public static Activities__c addActivityData(Activities__c activity) {
       system.debug( ' ************************* ' );
       try{
            System.debug(activity);
            upsert activity;
            return activity;
        } catch(exception e) {
           Utility.createErrorRecord(e.getMessage(), e.getStackTraceString(), e.getLineNumber(), e.getTypeName(), 'ChildrenController.addActivityData');  
           throw new AuraHandledException('Error addActivity: ' + e.getMessage());
       }
    }
    @AuraEnabled
    public static Medical_Providers__c addMedicalData(Medical_Providers__c medical) {
       system.debug( ' ************************* ' );
       try{
            System.debug(medical);
            upsert medical;
            return medical;
        } catch(exception e) {
           Utility.createErrorRecord(e.getMessage(), e.getStackTraceString(), e.getLineNumber(), e.getTypeName(), 'ChildrenController.addMedicalData');  
           throw new AuraHandledException('Error addMedical: ' + e.getMessage());
       }
    }
    @AuraEnabled
    public static void handleDelete(Id recordId, String objectName) {
        try {
            if (!Schema.getGlobalDescribe().containsKey(objectName)) {
                throw new invalidObjectException('Invalid object name: ' + objectName);
            }
            if (recordId != null) {
                System.debug('getting recordId::'+recordId);
                String query = 'SELECT Id FROM ' + objectName + ' WHERE Id = \'' + recordId + '\'';
                System.debug('getting query::'+query);
                delete Database.query(query);
            }
        } catch (Exception e) {
            Utility.createErrorRecord(e.getMessage(), e.getStackTraceString(), e.getLineNumber(), e.getTypeName(), 'ChildrenController.handleDelete');              
            throw new AuraHandledException('Error deleting record: ' + e.getMessage());
        }
    }
    @AuraEnabled
    public static Other_Income__c getOtherIncomeData(Id matterId) {
       system.debug( ' ************************* ' );
       try{
            List<Other_Income__c> otherIncomeList = [SELECT Id, All_other_Income_sources__c, Annual_Income__c, Average_Partner_Support__c, Average_Spousal_Support_from_Others__c, Child_Income__c, Child_Support_from_Other__c, Client__c, Contributions_from_Others_Monthly__c, CreatedById, Disability_SSDI_Monthly__c, Do_you_have_Retirement_Income__c, Expense_Account__c, Expense_Accounts_Monthly_Income__c, Interest_Dividends_Avg_Monthly__c, Interest_Dividends_Last_Monthly__c, Interest_Dividends_Last_Year__c, Investment_Non_Payroll_Ded_Avg_Month__c, Investment_Non_Payroll_Ded_Last_Month__c, Investment_Non_Payroll_Ded_Last_Year__c, LastModifiedById, Matter__c, Monthly_Income__c, Number_of_Months__c, Name, Other_Investment_Income_Avg_Monthly__c, Other_Investment_Income_Last_Month__c, Other_Investment_Income_Last_Year__c, OwnerId, Partner_Support_from_Others1month__c, Pension_Retirement_Fund_Monthly__c, Public_Assistance_TANF__c, Public_Assistance_TANF_Monthly__c, Related_To__c, Rental_Prop_Avg_Monthly__c, Rental_Prop_Last_Month__c, Rental_Prop_Last_Year__c, Renters_Name__c, Royalty_and_Other_Income_Monthly__c, Social_Security_Monthly__c, Source__c, Spousal_Support_from_Others1Month__c, Street_Address__c, Supp_Security_Income_SSI_Monthly__c, Support_rec_d_for_other_child_Monthly__c, Trust_Income_Avg_Monthly__c, Trust_Income_Last_Month__c, Trust_Income_Last_Year__c, Type_of_Income__c, Unemployment_Comp_Monthly__c, Unemployment_Comp_Last_Month__c, Unique_ID__c, Veterans_Benefit_Monthly__c, Worker_Comp_Avg_Monthly__c, Workers_Comp_Last_Month__c FROM Other_Income__c WHERE Matter__c = :matterId order by createddate asc LIMIT 1];
            if (otherIncomeList.size()>0){
                return otherIncomeList[0];
            } else  {
                Other_Income__c income= new Other_Income__c();  // create a default other income record
                income.Name='Other Income';
                income.Matter__c=matterId;
                insert income;
                income= [SELECT Id, All_other_Income_sources__c, Annual_Income__c, Average_Partner_Support__c, Average_Spousal_Support_from_Others__c, Child_Income__c, Child_Support_from_Other__c, Client__c, Contributions_from_Others_Monthly__c, CreatedById, Disability_SSDI_Monthly__c, Do_you_have_Retirement_Income__c, Expense_Account__c, Expense_Accounts_Monthly_Income__c, Interest_Dividends_Avg_Monthly__c, Interest_Dividends_Last_Monthly__c, Interest_Dividends_Last_Year__c, Investment_Non_Payroll_Ded_Avg_Month__c, Investment_Non_Payroll_Ded_Last_Month__c, Investment_Non_Payroll_Ded_Last_Year__c, LastModifiedById, Matter__c, Monthly_Income__c, Number_of_Months__c, Name, Other_Investment_Income_Avg_Monthly__c, Other_Investment_Income_Last_Month__c, Other_Investment_Income_Last_Year__c, OwnerId, Partner_Support_from_Others1month__c, Pension_Retirement_Fund_Monthly__c, Public_Assistance_TANF__c, Public_Assistance_TANF_Monthly__c, Related_To__c, Rental_Prop_Avg_Monthly__c, Rental_Prop_Last_Month__c, Rental_Prop_Last_Year__c, Renters_Name__c, Royalty_and_Other_Income_Monthly__c, Social_Security_Monthly__c, Source__c, Spousal_Support_from_Others1Month__c, Street_Address__c, Supp_Security_Income_SSI_Monthly__c, Support_rec_d_for_other_child_Monthly__c, Trust_Income_Avg_Monthly__c, Trust_Income_Last_Month__c, Trust_Income_Last_Year__c, Type_of_Income__c, Unemployment_Comp_Monthly__c, Unemployment_Comp_Last_Month__c, Unique_ID__c, Veterans_Benefit_Monthly__c, Worker_Comp_Avg_Monthly__c, Workers_Comp_Last_Month__c FROM Other_Income__c WHERE id=:income.id][0];
                return income;  //making sure all fields needed are returned
            }
        } catch(exception e) {
            Utility.createErrorRecord(e.getMessage(), e.getStackTraceString(), e.getLineNumber(), e.getTypeName(), 'ChildrenController.getOtherIncomeData');   
           throw new AuraHandledException('Error addMedical: ' + e.getMessage());
       }
    }
    @AuraEnabled
    public static List<Employment__c> getEmploymentData(Id matterId) {
       system.debug( ' ************************* ' );
       try{
            List<Employment__c> employment = [SELECT Id, Name, Date_Of_Hire__c, Date_Employment_Ended__c, Job_Title__c, Employer__c  FROM Employment__c WHERE Related_Matter__c = :matterId ];
            return employment;

        } catch(exception e) {
            Utility.createErrorRecord(e.getMessage(), e.getStackTraceString(), e.getLineNumber(), e.getTypeName(), 'ChildrenController.getEmploymentData');   
           throw new AuraHandledException('Error addMedical: ' + e.getMessage());
       }
    }
    @AuraEnabled
    public static List<Taxes__c> getTaxData(Id matterId) {
       system.debug( ' ************************* ' );
       try{
            List<Taxes__c> taxes = [SELECT Id, Name, Year__c, IRS_Form__c, Filing_Status__c, Taxable_Income__c  FROM Taxes__c WHERE Matter_ID__c = :matterId ];
            return taxes;

        } catch(exception e) {
            Utility.createErrorRecord(e.getMessage(), e.getStackTraceString(), e.getLineNumber(), e.getTypeName(), 'ChildrenController.getTaxData');   
           throw new AuraHandledException('Error addMedical: ' + e.getMessage());
       }
    }        
}