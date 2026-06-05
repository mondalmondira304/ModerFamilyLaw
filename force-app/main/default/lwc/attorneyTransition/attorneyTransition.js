import { LightningElement, api, track, wire } from 'lwc';

import updateMatter from "@salesforce/apex/MatterController.updateMatter"; //gets the first open matter for a user

import createFutureErrorRecord from "@salesforce/apex/Utility.createFutureErrorRecord";

export default class AttorneyTransition extends LightningElement {
    @api recordIdIn;  //id received from virtualAccountCreater
    @api retainingClientsIn;  //from the retaining clients checkbox on matter
    showSuccessMessage=false;
    todaysDate;
    decisionValue;  //to hold the decision value
    nameValue;  //to hold the full name
    showSpinner = false;     
    connectedCallback(){
        const today = new Date();
        const yyyy = today.getFullYear();
        const mm = String(today.getMonth() + 1).padStart(2, '0');
        const dd = String(today.getDate()).padStart(2, '0');
        this.todaysDate = `${yyyy}-${mm}-${dd}`;
        if (this.retainingClientsIn=="false"){
            this.retainingClientsIn=false;
        } else if (this.retainingClientsIn=="true"){
            this.retainingClientsIn=true;
        }        
    }
    get options() {
        if (this.retainingClientsIn) {
            return [
                { label: 'Stay with MFL', value: 'Stay with MFL' },
                { label: 'Stay with current attorney', value: 'Stay with current attorney' },
                { label: 'Seek new counsel', value: 'Stay with current attorney' },                
            ];
        }
        return [
            { label: 'Stay with MFL', value: 'Stay with MFL' },
            { label: 'Seek new counsel', value: 'Stay with current attorney' },     
        ];        
    }    
    get showSurvey() {
        return !this.showSuccessMessage;
    }
    async handleSubmit(event) {
        let passed=true;
        let nameValuefield = this.template.querySelector('.nameValue');
        nameValuefield.setCustomValidity('');
        nameValuefield.reportValidity();
        if (this.nameValue==undefined || this.nameValue==null){
            nameValuefield.setCustomValidity('Please type your name');
            nameValuefield.reportValidity();         
            passed=false;   
        }        
        let decisionValuefield = this.template.querySelector('.decisionValue');
        decisionValuefield.setCustomValidity('');
        decisionValuefield.reportValidity();
        if (this.decisionValue==undefined || this.decisionValue==null){
            decisionValuefield.setCustomValidity('Please select one choice.');
            decisionValuefield.reportValidity();
            passed=false;
        }
        if (!passed){
            return;
        }
        this.showSpinner = true;         
        let matter = {};
        let matterOut = {};
        matter['Id']=this.recordIdIn  ;  //populated from virtualAccountCreater
        matter['Retaining_Client_Decision__c']=this.decisionValue;
        matter['Retaining_Client_Signature__c']=this.nameValue;
        matter['Retaining_Client_Date__c']=this.todaysDate;     
        matterOut=await updateMatter({ matterIn: matter }); // to bypass sharing rules  
        if (matterOut.Id!=undefined && matterOut.Id!=null){
            this.showSuccessMessage=true;  //show the success page and hide the survey
        }
        this.showSpinner = false;     
    }
    handleNameValueChange(e){
        this.nameValue = e.target.value.trim();
        let nameValuefield = this.template.querySelector('.nameValue');
        nameValuefield.setCustomValidity('');
        nameValuefield.reportValidity();        
    }
    handleDecisionValueChange(e){
        this.decisionValue = e.target.value.trim();        
        let decisionValuefield = this.template.querySelector('.decisionValue');
        decisionValuefield.setCustomValidity('');
        decisionValuefield.reportValidity();        
    }
    handleRefresh() {
        //this.dispatchEvent(new RefreshEvent());  //need a handler for the event
        window.location.reload();
    }
}