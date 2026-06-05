import { LightningElement, api, track } from 'lwc';
import { FlowNavigationNextEvent } from 'lightning/flowSupport';
import updateAccount from '@salesforce/apex/VitalAccountController.updateAccount';

export default class SsClientApplicationAddress extends LightningElement {
    @api recordId;	    
    @track errorMessage = '';
    @track isLoading = false;
    acct={};
    acctInitialized=false;  //set after initializing the acct object

    handleChange(event){ //capture updated data to this.acct
        if(!this.acctInitialized){
            this.initializeAcct();
        }
        this.acct = { ...this.acct, [event.target.fieldName]: event.target.value };    
    }
    initializeAcct(){ //populate this.acct with the existing data
        const inputFields = this.template.querySelectorAll('lightning-input-field');
        this.acct['Id']=this.recordId;
        inputFields.forEach(field => {
            if (field.fieldName && field.value) {
                this.acct[field.fieldName] = field.value;
            }
        }); 
        this.acctInitialized=true;  
    }        
    handleSuccess(event) {
        this.isLoading = false;        
        //const fields = event.detail.fields;        
        this.errorMessage = '';
        // Proceed to next Flow screen
        //this.dispatchEvent(new FlowNavigationNextEvent({ detail: fields }));    is this needed?
        this.dispatchEvent(new CustomEvent("simplestart", { detail: 'ShowConsent' }));           
    }
    handleSave(event) {
        event.preventDefault();
        if(!this.acctInitialized){
            this.initializeAcct();
        }        
        let dataError=false;
        dataError=(this.acct.PersonMailingStreet==undefined ||this.acct.PersonMailingStreet==null||this.acct.PersonMailingStreet.trim()=='')? true : dataError; 
        dataError=(this.acct.PersonMailingCity==undefined ||this.acct.PersonMailingCity==null||this.acct.PersonMailingCity.trim()=='')? true : dataError;
        dataError=(this.acct.State_A__c==undefined ||this.acct.State_A__c==null||this.acct.State_A__c.trim()=='')? true : dataError; 
        dataError=(this.acct.PersonMailingCountry==undefined ||this.acct.PersonMailingCountry==null||this.acct.PersonMailingCountry.trim()=='')? true : dataError;
        dataError=(this.acct.PersonMailingPostalCode==undefined ||this.acct.PersonMailingPostalCode==null||this.acct.PersonMailingPostalCode.trim()=='')? true : dataError; 
        if (dataError==true)  return ;  // do not proceed                      
        if (this.isLoading) return;
        this.isLoading = true;     
        console.debug(this.acct);
        let accountResult=updateAccount({ acc: this.acct }); // to bypass sharing rules    
        this.handleSuccess();
    }
    handleError(event) {
        this.isLoading = false;
        this.errorMessage = event.detail.detail || 'An error occurred.';
    }
}