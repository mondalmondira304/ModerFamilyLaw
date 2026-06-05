import { LightningElement, api, track } from 'lwc';
import { ShowToastEvent } from 'lightning/platformShowToastEvent';
import updateAccount from '@salesforce/apex/VitalAccountController.updateAccount';
import createFutureErrorRecord from "@salesforce/apex/Utility.createFutureErrorRecord";

export default class SsApplicationForm extends LightningElement {
    @api recordId; 
    @track errorMessage = '';
    @track isLoading = false;
    @track ssn = '';
    @track errors = {
        PersonMobilePhone: {show: false, error: undefined},
        Social_Security_Number__c: {show: false, error: undefined},
    };
    acct={};
    acctInitialized=false;  //set after initializing the acct object

    get showNext(){
        return true;
    }   
    handleChange(event){ //capture updated data to this.acct
        if(!this.acctInitialized){
            this.initializeAcct();
        }
        this.acct = { ...this.acct, [event.target.fieldName]: event.target.value };    
    }
    handleSSNChange(event) { //whenever there is a change to a form field    
        this.errors.Social_Security_Number__c.show=false; //clear error display...validateFields function will do the validation
        this.handleChange(event);
    }  
    handlePhoneChange(event) { //whenever there is a change to a form field
        this.errors.PersonMobilePhone.show=false; //clear error display...validateFields function will do the validation
        this.handleChange(event);
    }     
    handleSuccess(event) {
        try {
            this.isLoading = false;        
            this.errorMessage = '';
            // Proceed to next Flow screen
            //this.dispatchEvent(new FlowNavigationNextEvent({ detail: fields }));    is this needed?
            this.dispatchEvent(new CustomEvent("simplestart", { detail: 'ShowSimpleStartAddress' }));       
        } catch (e){
            createFutureErrorRecord( {exceptionMessage: e.message ?? e.body.message, stackTrace: e.stack ?? e.body.stackTrace, lineNum: 0, errortype: 'Javascript', procname: 'ssClientApplicationForm.handleSuccess'}) ;                     
        }            
    }
    initializeAcct(){ //populate this.acct with the account data
        const inputFields = this.template.querySelectorAll('lightning-input-field');
        this.acct['Id']=this.recordId;
        inputFields.forEach(field => {
            if (field.fieldName && field.value) {
                this.acct[field.fieldName] = field.value;
            }
        }); 
        this.acctInitialized=true;  
    }
    handleSave(event) {
        try {         
            event.preventDefault();
            if ( !this.isLoading ) { 
                if(!this.acctInitialized){
                    this.initializeAcct();
                }
                this.acct['Id']=this.recordId;        
                console.debug(this.acct);
                if (this.validateFields(this.acct)!=='success') return;  //will run checks involving RegEx expressions                
                updateAccount({ acc: this.acct }); // to bypass sharing rules  
                this.handleSuccess();      
            }
        } catch (e){
            createFutureErrorRecord( {exceptionMessage: e.message ?? e.body.message, stackTrace: e.stack ?? e.body.stackTrace, lineNum: 0, errortype: 'Javascript', procname: 'ssClientApplicationForm.handleSave'}) ;                     
        }
    }
    validateFields(acct) {
        try {
            let dataError=false;         
            let phone = acct.PersonMobilePhone;     
            //first pattern is for domestic numbers while the second is for international numbers
            if ( /^(\+\d{1,2}\s)?\(?\d{3}\)?[\s.-]?\d{3}[\s.-]?\d{4}$/.test(phone)  || /^\+([0-9]{1,4})[-. ]?([0-9]{1,15})$/.test(phone) ) { 
                this.errors.PersonMobilePhone.show=false; 
            } else {
                dataError=true;  //data error condition...do not continue
                this.errors.PersonMobilePhone.show=true;
                this.errors.PersonMobilePhone.error='Please enter a valid domestic phone number with area code or an international phone number starting with + and country code.';
            }  
            let ssn = acct.Social_Security_Number__c;     
            if ( /^(?!000|9\d{2})\d{3}-?(?!00)\d{2}-?(?!0000)\d{4}$/.test(ssn) ) { 
                this.errors.Social_Security_Number__c.show=false; 
            } else {
                dataError=true;  //data error condition...do not continue
                this.errors.Social_Security_Number__c.show=true;
                this.errors.Social_Security_Number__c.error='Please enter a valid SSN consisting of nine digits with or without the - separator.  123456789 and 123-45-6789 are valid SSN examples.';
            }
            dataError=(acct.Gender__c==undefined ||acct.Gender__c==null||acct.Gender__c.trim()=='')? true : dataError; //check other fields
            dataError=(acct.PersonBirthdate==undefined ||acct.PersonBirthdate==null)? true : dataError;
            dataError=(acct.Birth_City__c==undefined||acct.Birth_City__c==null||acct.Birth_City__c.trim()=='')? true : dataError;
            dataError=(acct.Birth_State__c==undefined||acct.Birth_State__c==null||acct.Birth_State__c.trim()=='')? true : dataError;
            dataError=(acct.Birth_Country__c==undefined||acct.Birth_Country__c==null||acct.Birth_Country__c.trim()=='')? true : dataError;
            dataError=(acct.Current_Employer__c==undefined||acct.Current_Employer__c==null||acct.Current_Employer__c.trim()=='')? true : dataError;
            dataError=(acct.Job_Title__c==undefined||acct.Job_Title__c==null||acct.Job_Title__c.trim()=='')? true : dataError;                                                
            dataError=(acct.Annual_household_income__c==undefined||acct.Annual_household_income__c==null)? true : dataError;                        
            if (dataError==false)  return 'success';   
            else return 'failure';   
        } catch (error) {
            createFutureErrorRecord( {exceptionMessage: error.message ?? error.body.message, stackTrace: error.stack ?? error.body.stackTrace, lineNum: 0, errortype: 'Javascript', procname: 'ssClientApplicationForm.handleSSNChange'}) ;                     
        }  
    }   
    handleError(event) {
        try {
            this.isLoading = false;
            this.errorMessage = event.detail.detail || 'An error occurred.';
        } catch (e){
            createFutureErrorRecord( {exceptionMessage: e.message ?? e.body.message, stackTrace: e.stack ?? e.body.stackTrace, lineNum: 0, errortype: 'Javascript', procname: 'ssClientApplicationForm.handleError'}) ;                     
        } 
    }
    showToast(title, message, variant) {
        try {
            const event = new ShowToastEvent({
                title: title,
                message: message,
                variant: variant,
            });
            this.dispatchEvent(event);
        } catch (e){
            createFutureErrorRecord( {exceptionMessage: e.message ?? e.body.message, stackTrace: e.stack ?? e.body.stackTrace, lineNum: 0, errortype: 'Javascript', procname: 'ssClientApplicationForm.showToast'}) ;                     
        } 
    }       
}