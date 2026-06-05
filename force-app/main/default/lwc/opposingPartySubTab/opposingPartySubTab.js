import { LightningElement, api, wire, track } from 'lwc';
import { refreshApex } from '@salesforce/apex';
import { getRecord } from 'lightning/uiRecordApi';
import getAssociatedFiles from '@salesforce/apex/FileUploadController.getAssociatedFiles';
import getVersionDataUrl from '@salesforce/apex/FileUploadController.getVersionDataUrl';
import getOpposingPartiesForSelectdMatter from '@salesforce/apex/VitalAccountController.getOpposingPartiesForSelectdMatter';
import updateAccount from '@salesforce/apex/VitalAccountController.updateAccount';
import opposingLogo from '@salesforce/resourceUrl/opposingLogo';
import createFutureErrorRecord from "@salesforce/apex/Utility.createFutureErrorRecord";
import LOADERICON from '@salesforce/resourceUrl/LoaderIcon';
import contactOP from './contactOP.html';
import identityOP from './identityOP.html';
import familyOP from './familyOP.html';
import educationOP from './educationOP.html';
import militaryOP from './militaryOP.html';
import socialMediaOP from './socialMediaOP.html';
import serviceOfPurposeOP from './serviceOfPurposeOP.html';
import { ShowToastEvent } from 'lightning/platformShowToastEvent';
const FIELDS = [
   'Account.Spouse_Text__c'
];
export default class OpposingPartySubTab extends LightningElement {
    @api recordId = '001TH000009jH7c';
    @api childSubPages;
    @api pages;
    @api ciFormStatus;
    @api childMatterActivity;
    @track loaderIcon = LOADERICON;
    @track showServiceSpinner = false;
    @track showDataTable = true;
    @track fullName = '';
    @track showDetails = false;
    @track isEditMode = false;
    @track error;
    uploadedFile = ''; // Name of the uploaded file
    @track listOfUploadedIdentityFiles =[];
    emailErrorOP = true;
    phoneErrorOP = true;
    numberErrorOP = true;
    yearsOfCollegeErrorOP = true;
    yearsOfGraduateSchoolErrorOP = true;
    weightErrorOP = true;
    heightErrorOP = true;
    isMalingAddressOP = true;
    @track activeAccountId;
    isModalOpen = false;
    opposingLogoImg = opposingLogo;
    selectedRecordId = '';
    @track accountId;
    @track inMilitaryPicklistOptions = [];
    //New Change
    @track imageName =''   
    isEditing=false;  //set to true once a form field has been updated 

    connectedCallback() {
        try{
            getOpposingPartiesForSelectdMatter({matterId: this.childMatterActivity}).then(result=>{
                if (result) {
                    result = JSON.parse(JSON.stringify(result));
                    result.forEach(res => {
                        res.accLink = '/' + res.Id;
                    });
                    this.showServiceSpinner = false;
                    this.opposingParties = result;
                    this.activeAccountId = this.selectedRecordId  = this.opposingParties[0].Opposing_Party_a__r.Id;
                    this.error = null;
                    console.log('Oppossing Partyy  ---- ' + JSON.stringify(this.opposingParties));
                }            
            })
        } catch (error) {
            this.showServiceSpinner = false; 
            this.error = error;
            this.showToast('Error', error.message, 'error');
            this.disableButton=false;
            createFutureErrorRecord( {exceptionMessage: error.message ?? error.body.message, stackTrace: error.stack ?? error.body.stackTrace, lineNum: 0, errortype: 'Javascript', procname: 'opposingPartySubTab.connectedCallback'}) ;
        }
    }
    validateFields(){
        this.validateEmail(this.selectedAccount.PersonEmail);
        this.validatePhone(this.selectedAccount.PersonMobilePhone);
        this.validatePhone(this.selectedAccount.Phone);
        this.validateNumber(this.selectedAccount.Length_of_Residence__c);
        // this.validateYearsOfCollege(this.selectedAccount.Years_of_college__c);
        // this.validateYearsOfGraduateSchool(this.selectedAccount.Years_of_Graduate_School__c);
        // this.validateWeight(this.selectedAccount.Weight__c);
        // this.validateHeight(this.selectedAccount.Height__c);
        this.validateMailingAddress();
        this.checkForPhoneFields();
    }
    render (event) {
        console.log('SubPageName:  ',this.childSubPages);
        switch (this.childSubPages) {
            case 'OP-Contact':
                this.saveChanges(event);
                this.getFiles();  
                return contactOP;
            case 'OP-Identity':
                this.saveChanges(event);
                return identityOP;
            case 'OP-Family':
                this.saveChanges(event);
                return familyOP;
            case 'OP-Education':
                this.saveChanges(event);
                return educationOP;
            case 'OP-Military':
                this.saveChanges(event);
                return militaryOP;
            case 'OP-Social Media':
                this.saveChanges(event);
                return socialMediaOP;
            case 'OP-Service of Process':
                this.saveChanges(event);
                return serviceOfPurposeOP;
            default:
                //this.saveChanges(event);
                return contactOP;
        }
    }
    /* new 10/23 */
    setIsEditingTrue () { //event propagates back to virtualAccountCreater as bubbles and composed are set to true
        this.isEditing=true;
        this.dispatchEvent(new CustomEvent("isediting", { detail: true, bubbles: true, composed:true }));    
    }  
    setIsEditingFalse () { //event propagates back to virtualAccountCreater
        this.isEditing=false;
        this.dispatchEvent(new CustomEvent("isediting", { detail: false, bubbles: true, composed: true }));    
    }  
    saveChanges(event){
        try {
        if (this.currentChildSubPages!=this.childSubPages)  {
            this.handleAccountSave(event);
            this.currentChildSubPages=this.childSubPages;
        }
        } catch (error) {
            createFutureErrorRecord( {exceptionMessage: error.message ?? error.body.message, stackTrace: error.stack ?? error.body.stackTrace, lineNum: 0, errortype: 'Javascript', procname: 'opposingPartySubTab.handleSuccess'}) ;  
        }        
    }
    handleAccountSave(event) { //written to handle updates to the account object as we don't have access to it except through an Apex controller
        try {
            if (!this.isEditing) { return; } //no edits to save
            this.showServiceSpinner = true;
            const inputFields = this.template.querySelectorAll('lightning-input-field');
            let acct = {};
            acct['Id']=this.selectedRecordId  ;  //populated from the wire adapter but is known by the parent component already
            inputFields.forEach(field => {
                if (field.fieldName && field.value) {
                    acct[field.fieldName] = field.value;
                }
            });        
            //console.debug(acct);
            updateAccount({ acc: acct }); // to bypass sharing rules  
            this.handleSuccess();      
        } catch (error) {
            this.showServiceSpinner = false; 
            this.error = error;
            this.showToast('Error', error.message, 'error');
            this.disableButton=false;
            createFutureErrorRecord( {exceptionMessage: error.message ?? error.body.message, stackTrace: error.stack ?? error.body.stackTrace, lineNum: 0, errortype: 'Javascript', procname: 'opposingPartySubTab.handleAccountSave'}) ;                     
        }         
    }     
    handleOnChange(event) { //whenever there is a change to a form field
    try {
        this.setIsEditingTrue();  //fire an event so parent components know an edit was made
        console.log('input Change');
        } catch (error) {
            this.error = error;
            this.showToast('Error', error.message, 'error');
            this.disableButton=false;
            createFutureErrorRecord( {exceptionMessage: error.message ?? error.body.message, stackTrace: error.stack ?? error.body.stackTrace, lineNum: 0, errortype: 'Javascript', procname: 'opposingPartySubTab.handleOnChange'}) ;                     
        }             
    }
    handleSuccess(event) { //event from a successful form submission
        try {
            this.showServiceSpinner = false; 
            this.setIsEditingFalse();  // fire an event so parent components know an submit was made and that menu navigation is allowed
            //this.recordId = this.selectedRecordId =  event.detail.id;  //if it's an insert--never will be an insert so let's not do this
            this.dispatchEvent(
                    new ShowToastEvent({
                        title: 'Success',
                        message: 'Opposing party updated successfully',
                        variant: 'success',
                        mode: 'dismissable'
                    })
                );               
        } catch (error) {
                createFutureErrorRecord( {exceptionMessage: error.message ?? error.body.message, stackTrace: error.stack ?? error.body.stackTrace, lineNum: 0, errortype: 'Javascript', procname: 'opposingPartySubTab.handleSuccess'}) ;  
        }
    }  
    handleUploadFinished(evt){
        try {
            this.getFiles()
            .then(result => {       
                getVersionDataUrl ({recordId : this.uploadedFile.id})  //returns an URL referencing the photo
                .then(result=>{
                    let acct = {};
                    acct['Id']=this.selectedRecordId  ;  //populated from the wire adapter but is known by the parent component already
                    acct['Photo_URL__c'] = result;
                    updateAccount({ acc: acct });  //to attach the profile photo immediately to the opposing party
                    console.log('Account profile picture:  ', acct.Photo_URL__c);                    
                })                                           
            })      
        } catch (e){
        this.error = e;
        this.uploadedFile = undefined;
        createFutureErrorRecord( {exceptionMessage: e.message ?? e.body.message, stackTrace: e.stack ?? e.body.stackTrace, lineNum: 0, errortype: 'Javascript', procname: 'opposingPartySubPage.handleUploadFinished'}) ;                    
        }                                                 
    }     
    async handleSubmitOPSection(event) {  //....called from a event triggered on a button on the serviceOfPurposeOP page--only time this will be called....replaces saveRecord()
        try {
            this.showServiceSpinner = true; 
            this.handleAccountSave(event);  //to save off the account via an Apex controller
            //Something is preventing the form submit from completing successfully on the last of the income screens.  Maybe the form goes out of scope before the successHandler can fire.  run setIsEditingFalse().            
            this.setIsEditingFalse();  
            this.showServiceSpinner = false;
            if (this.ciFormStatus === 'Open') {
                this.isModalOpen = true;
            } else {
                this.closeModal();
            }                      
        } catch (e){
            createFutureErrorRecord( {exceptionMessage: e.message ?? e.body.message, stackTrace: e.stack ?? e.body.stackTrace, lineNum: 0, errortype: 'Javascript', procname: 'vitalSubPage.handleSubmitVitalSection'}) ;                     
        } 
    }
    /* new 10/23 */

    validateEmail(value) {
        const emailRegex = /^[^\s@]+@[^\s@]+\.[^\s@]+$/;
        this.emailErrorOP = emailRegex.test(value) ? true : false;
        console.log('this.emailErrorOP::',this.emailErrorOP);
        this.opposingChildValidation();
    }
    validatePhone(value) {
        const phonePattern = /^(?:[+][\d\s\-.,*()]{10,15}|[\d\s\-.,*()]{10,14})$/;
        if (!value) {
            this.phoneError = true;
        } else {
            this.phoneError = phonePattern.test(value) ? true : false;
        }
        console.log('this.phoneErrorOP::',this.phoneErrorOP);
        this.opposingChildValidation();
    }
    validateNumber(value) {
        const numberPattern = /^(?:[1-9]\d{0,2}|0)$/;
        this.numberErrorOP = numberPattern.test(value) ? true : false;
        console.log('this.numberErrorOP::',this.numberErrorOP);
        this.opposingChildValidation();
    }
    validateYearsOfCollege (value) {
        const isNumeric = /^\d+$/.test(value);
        if ( isNumeric || (Number(value) >= 0 && Number(value) <= 20) ) {
            this.yearsOfCollegeError = true;
        } else {
            this.yearsOfCollegeError = false;        
        }
        console.log('this.yearsOfCollegeErrorOP::',this.yearsOfCollegeErrorOP);       
        this.opposingChildValidation();
    }
    validateYearsOfGraduateSchool (value) {
        const isNumeric = /^\d+$/.test(value);
        if (isNumeric || (Number(value) >= 0 && Number(value) <= 20)) {
            this.yearsOfGraduateSchoolError = true;
        } else {
            this.yearsOfGraduateSchoolError = false;        
        }
        this.opposingChildValidation();
    }
    validateWeight (value) {
        const isNumeric = /^\d+$/;
        if (!value) {
            this.weightErrorOP = true;
        } else {
            this.weightErrorOP = isNumeric.test(value)? true : false;
            console.log('this.numberErrorOP::',this.weightErrorOP);      
        }
        this.opposingChildValidation(value);
    }
    validateHeight (value) {
        const heightPattern = /^(1[0-2]|[1-9])' ?(1[0-2]|[0-9])"$/; 
        if (!value) {
            this.heightErrorOP = true;
        } else {
            this.heightErrorOP = heightPattern.test(value) ? true : false;
            console.log('this.numberErrorOP::',this.heightErrorOP);
        }
        this.opposingChildValidation();
    }
    validateMailingAddress () {
        console.log('Inside validateMailingAddress line 411 ')
        if (this.selectedAccount.PersonMailingCity && this.selectedAccount.PersonMailingCountry && this.selectedAccount.PersonMailingPostalCode && this.selectedAccount.PersonMailingState && this.selectedAccount.PersonMailingStreet) {
            this.isMalingAddressOP = true;
        } else {
            this.isMalingAddressOP = false;
        }
        console.log('this.isMalingAddressOP::',this.isMalingAddressOP);
        
        this.opposingChildValidation();
        console.log('this.account::',this.selectedAccount);
    }
    opposingChildValidation () {
        console.log('inside opposingChildValidation');
        let validation;
        let value = [];
        value.push({emailErrorOP: this.emailErrorOP, phoneErrorOP: this.phoneErrorOP, numberErrorOP: this.numberErrorOP, yearsOfCollegeErrorOP: this.yearsOfCollegeErrorOP, yearsOfGraduateSchoolErrorOP: this.yearsOfGraduateSchoolErrorOP, weightErrorOP: this.weightErrorOP, heightErrorOP: this.heightErrorOP, isMalingAddressOP: this.isMalingAddressOP});
        if (this.emailErrorOP && this.phoneErrorOP && this.numberErrorOP && this.yearsOfCollegeErrorOP && this.yearsOfGraduateSchoolErrorOP && this.weightErrorOP && this.heightErrorOP && this.isMalingAddressOP) {
            validation = false;
        } else {
            validation = true;
        }
        console.log('First Validation::',validation);
        console.log('value::',value);
        const event = new CustomEvent('validationchild', {
            detail: {
                validation: validation,
                value: value
            }
        });
        this.dispatchEvent(event);
    }
    showToast(title, message, variant) {
        this.dispatchEvent(new ShowToastEvent({ title, message, variant }));
    }
    /*saveRecord() { 
        if (!this.emailErrorOP || !this.phoneErrorOP || !this.numberErrorOP || !this.yearsOfCollegeErrorOP ||!this.yearsOfGraduateSchoolErrorOP || !this.weightErrorOP || !this.heightErrorOP || !this.isMalingAddressOP) {
            let errorMsg = '';
            if (!this.weightErrorOP) {
                errorMsg = 'Please check weight field; value should be between 0 and 500.';
            } else if (!this.heightErrorOP) {
                errorMsg = 'Please enter height in feet and inches, e.g., 5\'7".';
            } else if (!this.emailErrorOP) {
                errorMsg = 'Invalid email address.';
            } else if (!this.phoneErrorOP) {
                errorMsg = 'Invalid phone number.';
            } else if (!this.numberErrorOP) {
                errorMsg = 'Invalid Length of Residence entered .';
            } else if (!this.yearsOfCollegeErrorOP) {
                errorMsg = 'Please check the number of college years.';
            } else if (!this.yearsOfGraduateSchoolErrorOP) {
                errorMsg = 'Please check the number of graduate school years.';
            } else if (!this.isMalingAddressOP) {
                errorMsg = 'Mailing address is invalid or incomplete.';
            }
            this.showToast('Error', errorMsg, 'error');
        } else {
            this.showServiceSpinner = true;
            this.selectedAccount.Name = undefined;       
            updateAccount({ acc: this.selectedAccount })
                .then(result => {
                    this.selectedAccount = result;
                    console.log('getting select Account::',this.selectedAccount);
                    this.error = undefined;
                    this.showServiceSpinner = false;
                    const event = new ShowToastEvent({
                        title: 'Success',
                        message: 'Account updated Successfully',
                        variant: 'success',
                        mode: 'dismissable'
                    });
                    this.dispatchEvent(event);
                    console.log('Record Submited successfully');
                    if (this.ciFormStatus === 'Open') {
                        this.isModalOpen = true;
                    } else {
                        this.closeModal();
                    }
                    // Refresh the wired data
                    return refreshApex(this.wiredAccount);
                })
                .catch(error => {
                    this.error = error;
                    let errorMessage =  'Account update failed!  Please contact support.';
                    if (error && error.body && error.body.message) {
                        errorMessage = error.body.message;
                    }
                    const evt = new ShowToastEvent({
                        title: 'Error',
                        message: errorMessage,
                        variant: 'error',
                        mode: 'dismissable'
                    });
                    this.dispatchEvent(evt);
                    createFutureErrorRecord( {exceptionMessage: error.message ?? error.body.message, stackTrace: error.stack ?? error.body.stackTrace, lineNum: 0, errortype: 'Javascript', procname: 'opposingPartySubTab.saveRecord'}) ;
                    console.error('Exception thrown:  ', error, 'stack trace:  ', error.stack);                      
                });
        }
    }*/
    get acceptedFormats() {
        return ['.pdf', '.png', '.jpg', '.jpeg'];  //JPG, PNG
    }    
    async getFiles()    { 
    try {     
        if (this.selectedRecordId==undefined || this.selectedRecordId==null || this.selectedRecordId=='') { return; } //
        let files =  await getAssociatedFiles ( { recordId: this.selectedRecordId });
        this.error = undefined;            
            this.uploadedFile  = files ? {   name: files[0].Title, id: files[0].Id } : {};  ///just get the first one as that is the most recent uploaded file -- used for profile photos so we want the latest one               
            this.listOfUploadedIdentityFiles = files ? files.map((aFile) => {
                return {    name: aFile.Title,  id: aFile.Id    }
            }) : [];                                    
        } catch (e){
            this.error = e;
            this.uploadedFile = undefined;
            this.listOfUploadedIdentityFiles  = undefined;
            createFutureErrorRecord( {exceptionMessage: e.message ?? e.body.message, stackTrace: e.stack ?? e.body.stackTrace, lineNum: 0, errortype: 'Javascript', procname: 'opposingPartySubPage.getFiles'}) ;                    
        }
    }
    checkForPhoneFields() {
        ['Phone', 'PersonMobilePhone','Social_Security_Number__c'].forEach((field) => {
            if (this.selectedAccount[field] && (field === 'Phone' || field === 'PersonMobilePhone')) {
                this.runPhoneMethod(field, this.selectedAccount[field]);
            } else if (this.selectedAccount[field] && field === 'Social_Security_Number__c') {
                this.runSSNMethods(field, this.selectedAccount[field]);
            }
        });
    }
    runPhoneMethod(field, value) {
        const cleaned = ('' + value).replace(/\D/g, '');
        const match = cleaned.match(/^(\d{3})(\d{3})(\d{4})$/);
        console.log('Getting mobile Phone : ');
        if (field === 'Phone') {
            this.updatedPhone = match ? `(${match[1]}) ${match[2]}-${match[3]}` : value;
            console.log('Enter in Personal Mobille Phone : ',this.updatedPhone);
        } else {
            this.updatedPersonMobilePhone = match ? `(${match[1]}) ${match[2]}-${match[3]}` : value;
        }
    }
    runSSNMethods(field, value) {
        const cleaned = ('' + value).replace(/\D/g, '');
        const match = cleaned.match(/^(\d{3})(\d{2})(\d{4})$/);
        this.updateSSNNumber = match ? `${match[1]}-${match[2]}-${match[3]}` : value;
    }
    get manageNextANDSAVEButtons () {
        if (this.pages === 'Opposing Party' && this.childSubPages === 'OP-Service of Process') {
            return true;
        }
        return false;
    }
    closeModal () {
        setTimeout(() => {     
            this.isModalOpen = false;
            const event = new CustomEvent('submitchild', {
                detail: true
            });
            this.dispatchEvent(event);
    },    1500); }
}