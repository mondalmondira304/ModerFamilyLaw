export const CONSTANT = {


    DATA_CONFIG:{
        Activities__r: {

            fields: ['Activities__c.Id', 'Activities__c.Name', 'Activities__c.Activity_Type__c', 'Activities__c.Weekly_Schedule__c',
                'Activities__c.Reason_for_Treatment__c', 'Activities__c.Child_Name__c', 'Activities__c.Child_Name__r.Name'],
            
            columns: [
                {
                    type: 'button',
                    label: 'Activity Name',
                    typeAttributes: {
                        label: { fieldName: 'Name' },
                        name: 'Activities__c',
                        variant: 'base'
                    }
                },
                { label: 'Activity Type', fieldName: 'Activity_Type__c', type: 'text' },
                { label: 'Weekly Schedule', fieldName: 'Weekly_Schedule__c', type: 'text' }
            ]
        },

        Medical_Providers__r: {

            fields: ['Medical_Providers__c.Id', 'Medical_Providers__c.Name', 'Medical_Providers__c.Medical_Clinic_s_Name__c', 'Medical_Providers__c.Type_of_Provider__c',
                'Medical_Providers__c.Last_Seen_by_this_Provider__c'],
            
            columns: [
                {
                    type: 'button',
                    label: 'Medical Providers Name',
                    typeAttributes: {
                        label: { fieldName: 'Name' },
                        name: 'Medical_Providers__c',
                        variant: 'base'
                    }
                },
                { label: 'Heath Care Clinics Name', fieldName: 'Medical_Clinic_s_Name__c', type: 'text' },
                { label: 'Type of Provider', fieldName: 'Type_of_Provider__c', type: 'text' },
                { label: 'Last Seen by this Provider', fieldName: 'Last_Seen_by_this_Provider__c', type: 'text' }
            ]
        },


        // -------------------- Children Nested Tab Section End ----------------- ----------

        // -------------------- Asset Tab Section Start ----------------- ----------

        Housing__r: {
            fields: ['Housing__c.Id', 'Housing__c.Name', 'Housing__c.Joint__c',
                'Housing__c.Home_Equity_Estimate__c'],
            
            columns: [
                {
                    type: 'button',
                    label: 'Real Property Address',
                    typeAttributes: {
                        label: { fieldName: 'Name' },
                        name: 'Housing__c',
                        variant: 'base'
                    }
                },
                { label: 'Joint', fieldName: 'Joint__c', type: 'text' },
                { label: 'Home Equity Estimate', fieldName: 'Home_Equity_Estimate__c', type: 'text' }
            ]
        },

        Housing1__r: {
            fields: ['Housing__c.Id', 'Housing__c.Name', 'Housing__c.Joint__c',
                'Housing__c.Home_Equity_Estimate__c'],
            
            columns: [
                {
                    type: 'button',
                    label: 'Real Property Address',
                    typeAttributes: {
                        label: { fieldName: 'Name' },
                        name: 'Housing__c',
                        variant: 'base'
                    }
                },
                { label: 'Joint', fieldName: 'Joint__c', type: 'text' },
                { label: 'Home Equity Estimate', fieldName: 'Home_Equity_Estimate__c', type: 'text' }
            ]
        },

        Vehicles__r: {
            fields: ['Vehicle__c.Id', 'Vehicle__c.Name', 'Vehicle__c.Marital_or_Separate__c',
                'Vehicle__c.Loan_Balance__c', 'Vehicle__c.Insurance_Registration_Tax_Monthly__c',
                'Vehicle__c.Year__c','Vehicle__c.Make__c','Vehicle__c.Model__c','Vehicle__c.Client_Estimate_of_Value__c'],
            
            columns: [
                {
                    type: 'button',
                    label: 'Vehicle Name',
                    typeAttributes: {
                        label: { fieldName: 'Name' },
                        name: 'Vehicle__c',
                        variant: 'base'
                    }
                },
                { label: 'Marital or Separate', fieldName: 'Marital_or_Separate__c', type: 'text' },
                { label: 'Loan Balance', fieldName: 'Loan_Balance__c', type: 'text' },
                { label: 'Insurance Registration Tax_Monthly', fieldName: 'Insurance_Registration_Tax_Monthly__c', type: 'text' },
                { label: 'Year', fieldName: 'Year__c', type: 'text' },
                { label: 'Make', fieldName: 'Make__c', type: 'text' },
                { label: 'Model', fieldName: 'Model__c', type: 'text' },
                { label: 'Our Value', fieldName: 'Client_Estimate_of_Value__c', type: 'text' }
            ]
        }, 

        Life_Insurance_Client__r: {
            fields: ['Life_Insurance__c.Id', 'Life_Insurance__c.Name', 'Life_Insurance__c.Type_of_Policy__c',
                'Life_Insurance__c.Face_Amount_of_Policy__c', 'Life_Insurance__c.Joint__c','Life_Insurance__c.Client__r.Name'],
            
            columns: [
                {
                    type: 'button',
                    label: 'Policy Name',
                    typeAttributes: {
                        label: { fieldName: 'Name' },
                        name: 'Life_Insurance__c',
                        variant: 'base'
                    }
                },
                { label: 'Type of Policy', fieldName: 'Type_of_Policy__c', type: 'text' },
                { label: 'Face Amount of Policy', fieldName: 'Face_Amount_of_Policy__c', type: 'text' },
                { label: 'Joint', fieldName: 'Joint__c', type: 'text' }
            ]
        },

        Furniture_Personal_Property__r: {
            fields: ['Furniture_Personal_Property__c.Id', 'Furniture_Personal_Property__c.Name', 'Furniture_Personal_Property__c.Property_Type__c',
                'Furniture_Personal_Property__c.Marital_Separate__c', 'Furniture_Personal_Property__c.Estimated_Value_as_of_Today__c'],
            
            columns: [
                {
                    type: 'button',
                    label: 'Policy Name',
                    typeAttributes: {
                        label: { fieldName: 'Name' },
                        name: 'Furniture_Personal_Property__c',
                        variant: 'base'
                    }
                },
                { label: 'Property Type', fieldName: 'Property_Type__c', type: 'text' },
                { label: 'Marital Separate', fieldName: 'Marital_Separate__c', type: 'text' },
                { label: 'Estimated Value as of Today', fieldName: 'Estimated_Value_as_of_Today__c', type: 'text' }
            ]
        }, 

        Bank_Investment_Accounts__r: {
            fields: ['Bank_Account__c.Id', 'Bank_Account__c.Name', 'Bank_Account__c.Name_of_Bank__c',
                'Bank_Account__c.Type_of_Account__c', 'Bank_Account__c.Marital_or_Separate__c','Bank_Account__c.Petitioner__c'],
            
            columns: [
                {
                    type: 'button',
                    label: 'Bank Account Name',
                    typeAttributes: {
                        label: { fieldName: 'Name' },
                        name: 'Bank_Account__c',
                        variant: 'base'
                    }
                },
                { label: 'Name of Bank', fieldName: 'Name_of_Bank__c', type: 'text' },
                { label: 'Type of Account', fieldName: 'Type_of_Account__c', type: 'text' },
                { label: 'Petitionert', fieldName: 'Petitioner__c', type: 'text' },
                { label: 'Marital or Separate', fieldName: 'Marital_or_Separate__c', type: 'text' }
            ]
        }, 

        Investment_Account__r: {
            fields: ['Investment_Account__c.Id', 'Investment_Account__c.Name', 'Investment_Account__c.TYPE_OF_ACCOUNT__c',
                'Investment_Account__c.NAME_OF_BANK__c', 'Investment_Account__c.MARITAL_OR_SEPARATE__c'],
            
            columns: [
                {
                    type: 'button',
                    label: 'Name',
                    typeAttributes: {
                        label: { fieldName: 'Name' },
                        name: 'Investment_Account__c',
                        variant: 'base'
                    }
                },
                { label: 'Type of Account', fieldName: 'TYPE_OF_ACCOUNT__c', type: 'text' },
                { label: 'Name of Bank', fieldName: 'NAME_OF_BANK__c', type: 'text' },
                { label: 'Marital or Separate', fieldName: 'MARITAL_OR_SEPARATE__c', type: 'text' }
            ]
        },  

        Retirement_Account_Client__r: {
            fields: ['Retirement_Account__c.Id', 'Retirement_Account__c.Name', 'Retirement_Account__c.Name_of_Retirement_Bank__c',
                'Retirement_Account__c.Type_of_Retirement_Account__c', 'Retirement_Account__c.Marital_or_Separate__c'],
            
            columns: [
                {
                    type: 'button',
                    label: 'Retirement Account Name',
                    typeAttributes: {
                        label: { fieldName: 'Name' },
                        name: 'Retirement_Account__c',
                        variant: 'base'
                    }
                },
                { label: 'Name of Retirement Bank', fieldName: 'Name_of_Retirement_Bank__c', type: 'text' },
                { label: 'Type of Retirement Account', fieldName: 'Type_of_Retirement_Account__c', type: 'text' },
                { label: 'Marital or Separate', fieldName: 'Marital_or_Separate__c', type: 'text' }
            ]
        },

        Additional_Asset_Client__r: {
            fields: ['Additional_Asset__c.Id', 'Additional_Asset__c.Name', 'Additional_Asset__c.Asset_Value__c',
                'Additional_Asset__c.Type_of_Additional_Asset__c', 'Additional_Asset__c.Marital_or_Separate__c'],
            
            columns: [
                {
                    type: 'button',
                    label: 'Additional Asset Name',
                    typeAttributes: {
                        label: { fieldName: 'Name' },
                        name: 'Additional_Asset__c',
                        variant: 'base'
                    }
                },
                { label: 'Asset Value', fieldName: 'Asset_Value__c', type: 'text' },
                { label: 'Type of Additional Asset', fieldName: 'Type_of_Additional_Asset__c', type: 'text' },
                { label: 'Marital or Separate', fieldName: 'Marital_or_Separate__c', type: 'text' }
            ]
        }, 

        // -------------------- Asset Tab Section End ----------------- ----------
        // -------------------- Income Tab Section Start ----------------- ----------


        Employment__r: {
            fields: ['Employment__c.Id', 'Employment__c.Name', 'Employment__c.Length_of_Employment__c',
                'Employment__c.Monthly_Gross_Income__c'],
            
            columns: [
                {
                    type: 'button',
                    label: 'Employment Name',
                    typeAttributes: {
                        label: { fieldName: 'Name' },
                        name: 'Employment__c',
                        variant: 'base'
                    }
                },
                { label: 'Length of Employment (Yrs)', fieldName: 'Length_of_Employment__c', type: 'text' },
                { label: 'Monthly Gross Income', fieldName: 'Monthly_Gross_Income__c', type: 'text' }
            ]
        },

        Other_Incomes__r: {
            fields: ['Other_Income__c.Id', 'Other_Income__c.Name', 'Other_Income__c.Type_of_Income__c',
                'Other_Income__c.Source__c','Other_Income__c.Monthly_Income__c'],
            
            columns: [
                {
                    type: 'button',
                    label: 'Other Income Name',
                    typeAttributes: {
                        label: { fieldName: 'Name' },
                        name: 'Other_Income__c',
                        variant: 'base'
                    }
                },
                { label: 'Type of Income', fieldName: 'Type_of_Income__c', type: 'text' },
                { label: 'Source', fieldName: 'Source__c', type: 'text' },
                { label: 'Monthly Income', fieldName: 'Monthly_Income__c', type: 'text' }
            ]
        }, 
        Taxes__r: {
            fields: ['Taxes__c.Id', 'Taxes__c.Name', 'Taxes__c.Year__c',
                'Taxes__c.IRS_Form__c','Taxes__c.Filing_Status__c'],
            
            columns: [
                {
                    type: 'button',
                    label: 'Taxes Name',
                    typeAttributes: {
                        label: { fieldName: 'Name' },
                        name: 'Taxes__c',
                        variant: 'base'
                    }
                },
                { label: 'Tax Year', fieldName: 'Year__c', type: 'text' },
                { label: 'IRS Form', fieldName: 'IRS_Form__c', type: 'text' },
                { label: 'Filing Status', fieldName: 'Filing_Status__c', type: 'text' }
            ]
        },

        // -------------------- Income Tab Section End ----------------- ----------
        // -------------------- Debit Tab Section Start ----------------- ----------


        Credit_Card__r: {
            fields: ['Credit_Card__c.Id', 'Credit_Card__c.Name', 'Credit_Card__c.Marital_or_Separate__c',
                'Credit_Card__c.Monthly_Payment__c','Credit_Card__c.Credit_Card_Balance__c'],
            
            columns: [
                {
                    type: 'button',
                    label: 'Credit Card',
                    typeAttributes: {
                        label: { fieldName: 'Name' },
                        name: 'Credit_Card__c',
                        variant: 'base'
                    }
                },
                { label: 'Marital or Separate', fieldName: 'Marital_or_Separate__c', type: 'text' },
                { label: 'Monthly Payment', fieldName: 'Monthly_Payment__c', type: 'text' },
                { label: 'Credit Card Balance', fieldName: 'Credit_Card_Balance__c', type: 'text' }
            ]
        }, 

        Debts__r: {
            fields: ['Debt__c.Id', 'Debt__c.Name', 'Debt__c.Marital_or_Separate_Property__c',
                'Debt__c.Type__c','Debt__c.Balance__c'],
            
            columns: [
                {
                    type: 'button',
                    label: 'Debt Name',
                    typeAttributes: {
                        label: { fieldName: 'Name' },
                        name: 'Debt__c',
                        variant: 'base'
                    }
                },
                { label: 'Marital or Separate', fieldName: 'Marital_or_Separate_Property__c', type: 'text' },
                { label: 'Type', fieldName: 'Type__c', type: 'text' },
                { label: 'Balance', fieldName: 'Balance__c', type: 'text' }
            ]
        },

        Debts1__r: {
            fields: ['Debt__c.Id', 'Debt__c.Name', 'Debt__c.Marital_or_Separate_Property__c',
                'Debt__c.Type__c','Debt__c.Balance__c'],
            
            columns: [
                {
                    type: 'button',
                    label: 'Debt Name',
                    typeAttributes: {
                        label: { fieldName: 'Name' },
                        name: 'Debt__c',
                        variant: 'base'
                    }
                },
                { label: 'Marital or Separate', fieldName: 'Marital_or_Separate_Property__c', type: 'text' },
                { label: 'Type', fieldName: 'Type__c', type: 'text' },
                { label: 'Balance', fieldName: 'Balance__c', type: 'text' }
            ]
        },

        // -------------------- Debit Tab Section Start ----------------- ----------
    

    }

}