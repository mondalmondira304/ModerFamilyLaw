import { LightningElement, api, wire, track } from 'lwc';
import getAccountDetails from '@salesforce/apex/VitalAccountController.getAccountDetails';
import { getRecord } from 'lightning/uiRecordApi';
import Id from '@salesforce/user/Id';
import vitalLogo from '@salesforce/resourceUrl/vitalLogo';
import { refreshApex } from '@salesforce/apex';
import updateAccount from '@salesforce/apex/VitalAccountController.updateAccount';
import deleteFileAndDocument from '@salesforce/apex/FileUploadController.deleteFileAndDocument';
import getVersionDataUrl from '@salesforce/apex/FileUploadController.getVersionDataUrl';
import getAssociatedFiles from '@salesforce/apex/FileUploadController.getAssociatedFiles';
import contact from './contact.html';
import identity from './identity.html';
import marriage from './marriage.html';
import education from './education.html';
import military from './military.html';
import currentFamily from './currentFamily.html';
import socialMedia from './socialMedia.html';
import { ShowToastEvent } from 'lightning/platformShowToastEvent';
import createFutureErrorRecord from "@salesforce/apex/Utility.createFutureErrorRecord";
const FIELDS = [
   'Account.Spouse_Text__c'
];
export default class VitalSubPage extends LightningElement {
    @api childSubPages;
    currentChildSubPages='Contact';  // to keep track of the current form.  Contact is the first form so set it here.
    @api pages;
    @api ciFormStatus;
    @api selectedMatterId;  
    matter; //we need to access the name_change__c checkbox to conditionally render a field on the marriage form
    @track wiredMatter;  //used in refreshapex calls
    @track accountId;
    userId = Id;
    showServiceSpinner;
    uploadedContactFile = '';
    @track listOfUploadedIdentityFiles = [];
    @track uploadProfileFile =''; //file containing the profile picture
    vitalLogoImg = vitalLogo;
    isModalOpen = false;
    emailError = true;
    phoneError = true;
    numberError = true;
    yearsOfCollegeError = true;
    yearsOfGraduateSchoolError = true;
    adultsInHouseholdError = true;
    childrenOfThisRelationshipError = true;
    socialSecurityError = true;
    isMalingAddress = true;
    //wiredAccount;
    dataLoaded = false;
    fieldHelpTextMap = {};
    selectedRecordId = '';
    currentField='';  //used to track the field currently being edited.
    nextSubmitScreen=false; // if this function is called from a "Next" or "Submit" button, commit the record
    isEditing=false;  //set to true once a form field has been updated    

    /* 10/12 */
    @wire(getRecord, { recordId: '$selectedMatterId', fields: ["Matters__c.Id","Matters__c.Name_Change__c","Matters__c.New_Restored_Name__c"] })
    matter;  //why not this.matter?
    
    @wire(getAccountDetails, {  })
    wiredAccountHandler(result) {
        try {
            //this.wiredAccount = result;
            const { data, error } = result; 
            if (data) {
                //this.account = data.acc;
                //this.matter = data.matter;
                this.error = null;
                //this.checkForPhoneFields();  10/6 Don't check on load
                this.selectedRecordId = data.acc.Id;  //not really 
                // this.validateFields(); commented out 8/27
            } else if (error) {
                this.error = error;
                //this.account = null;
            }
        } catch (e){
            createFutureErrorRecord( {exceptionMessage: e.message ?? e.body.message, stackTrace: e.stack ?? e.body.stackTrace, lineNum: 0, errortype: 'Javascript', procname: 'vitalSubPage.getAccountDetails'}) ;
        }
    }
    /*validateFields(){ commented out 8/27
        this.validateEmail(this.account.PersonEmail);
        this.validatePhone(this.account.Phone);
        this.validatePhone(this.account.PersonMobilePhone);
        this.validateNumber(this.account.Length_of_Residence__c); 
        this.validateYearsOfCollege(this.account.Years_of_college__c); 
        this.validateYearsOfGraduateSchool(this.account.Years_of_Graduate_School__c); 
        this.validateMailingAddress();
    }*/
    saveChanges(event){
        if (this.currentChildSubPages=='Marriage' && this.currentChildSubPages!=this.childSubPages){                
            this.handleSubmitForm(event);  //as the marriage page references the matters record, we can submit the form directly
            this.currentChildSubPages=this.childSubPages;
        }   else if (this.currentChildSubPages!=this.childSubPages){
            this.handleAccountSave(event);
            this.currentChildSubPages=this.childSubPages;
        }        
    }
    render (event) {
        switch (this.childSubPages) {
            case 'Contact':
                this.saveChanges(event);
                return contact;
            case 'Identity':
                this.saveChanges(event);
                this.getFiles();  //get a list of identity files
                return identity;
            case 'Marriage':
                this.saveChanges(event);              
                return marriage;
            case 'Education':
                this.saveChanges(event);
                return education;
            case 'Military':
                this.saveChanges(event);
                return military;
            case 'Current Family':
                this.saveChanges(event);
                return currentFamily;
            case 'Social Media':
                this.saveChanges(event);
                return socialMedia;
            default:
                this.saveChanges(event);
                this.childSubPages='Contact';
                return contact;
        }
    }
    get manageNextANDSAVEButtons () {
        if (this.pages === 'Vitals' && this.childSubPages === 'Social Media') {
            return true;
        }
        return false;
    }

    handleNameChange (event){ // the Name_Change__c checkbox
        try {
            const field = event.target.dataset.field;
            const value = event.target.value;
            this.matter = { ...this.matter };
            if (event?.currentTarget?.type === 'checkbox') {
                this.matter[field] = event.target.checked;
            } else {
                this.matter[field] = value;
            }
            this.handleOnChange(event);
        } catch (e){
            createFutureErrorRecord( {exceptionMessage: e.message ?? e.body.message, stackTrace: e.stack ?? e.body.stackTrace, lineNum: 0, errortype: 'Javascript', procname: 'vitalSubPage.handleNameChange'}) ;                     
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
            createFutureErrorRecord( {exceptionMessage: error.message ?? error.body.message, stackTrace: error.stack ?? error.body.stackTrace, lineNum: 0, errortype: 'Javascript', procname: 'vitalSubPage.handleOnChange'}) ;                     
        }             
    }

    showToast(title, message, variant) {
        this.dispatchEvent(new ShowToastEvent({ title, message, variant }));
    }
    setIsEditingTrue () { //event propagates back to virtualAccountCreater as bubbles and composed are set to true
        this.isEditing=true;
        this.dispatchEvent(new CustomEvent("isediting", { detail: true, bubbles: true, composed:true }));    
    }  
    setIsEditingFalse () { //event propagates back to virtualAccountCreater
        this.isEditing=false;
        this.dispatchEvent(new CustomEvent("isediting", { detail: false, bubbles: true, composed: true }));    
    }  
    handleSuccess(event) { //event from a successful form submission
        try {
            this.showServiceSpinner = false; 
            this.setIsEditingFalse();  // fire an event so parent components know an submit was made and that menu navigation is allowed
            //this.recordId = this.selectedRecordId =  event.detail.id;  //if it's an insert--never will be an insert so let's not do this
            this.dispatchEvent(
                    new ShowToastEvent({
                        title: 'Success',
                        message: 'Account and Matter updated successfully',
                        variant: 'success',
                        mode: 'dismissable'
                    })
                );               
        } catch (error) {
                createFutureErrorRecord( {exceptionMessage: error.message ?? error.body.message, stackTrace: error.stack ?? error.body.stackTrace, lineNum: 0, errortype: 'Javascript', procname: 'incomeSubTab.handleSuccess'}) ;  
        }
    }  

    handleSubmitForm(event) { // 10/10 will only work when saving the marriage form which only references matter--event comes in empty as the button is on the grandparent object so the event only is in scope there
    try {
        if (!this.isEditing) { return; } //no edits to save
        this.showServiceSpinner = true; 
        const inputFields = this.template.querySelectorAll('lightning-input-field');  //have to query the input fields separately
        const fieldsToSubmit = {};
        inputFields.forEach(field => {
            if (field.fieldName && field.value !== undefined) {
                fieldsToSubmit[field.fieldName] = field.value;
            }
        });
            this.template.querySelector('lightning-record-edit-form').submit(fieldsToSubmit);
        } catch (error) {
            this.showServiceSpinner = false; 
            this.error = error;
            this.showToast('Error', error.message, 'error');
            this.disableButton=false;
            createFutureErrorRecord( {exceptionMessage: error.message ?? error.body.message, stackTrace: error.stack ?? error.body.stackTrace, lineNum: 0, errortype: 'Javascript', procname: 'vitalSubPage.handleSubmitForm'}) ;                     
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
            createFutureErrorRecord( {exceptionMessage: error.message ?? error.body.message, stackTrace: error.stack ?? error.body.stackTrace, lineNum: 0, errortype: 'Javascript', procname: 'vitalSubPage.handleAccountSave'}) ;                     
        }         
    }    

    async handleSubmitVitalSection(event) {  //....called from a event triggered on a button on the socialMedia page--only time this will be called....
        try {
            if (!this.emailError || !this.phoneError || !this.numberError || !this.yearsOfCollegeError ||!this.yearsOfGraduateSchoolError || !this.isMalingAddress || !this.socialSecurityError || !this.childrenOfThisRelationshipError) {
                const validations = [
                    { isValid: this.socialSecurityError, message: 'Please enter a valid Social Security Number.' },
                    { isValid: this.emailError, message: 'Invalid email address.' },
                    { isValid: this.phoneError, message: 'Invalid phone number.' },
                    { isValid: this.numberError, message: 'Invalid Length of Residence entered.' },
                    { isValid: this.yearsOfCollegeError, message: 'Please check the number of college years.' },
                    { isValid: this.yearsOfGraduateSchoolError, message: 'Please check the number of graduate school years.' },
                    { isValid: this.isMalingAddress, message: 'Mailing address is invalid or incomplete.' },
                    { isValid: this.childrenOfThisRelationshipError, message: 'Invalid or incomplete child relationship.' }
                ];
                const errorMessages = validations
                    .filter(validation => !validation.isValid)
                    .map(validation => validation.message);
                if (errorMessages.length > 0) {
                    this.showToast('Validation Errors', errorMessages.join('\n'), 'error');
                }
            } else {
                //this.showServiceSpinner = true; 
                this.handleAccountSave(event);  //to save off the account via an Apex controller
                //Something is preventing the form submit from completing successfully on the last of the income screens.  Maybe the form goes out of scope before the successHandler can fire.  run setIsEditingFalse().            
                this.setIsEditingFalse();  
                if (this.ciFormStatus === 'Open') {
                    this.isModalOpen = true;
                } else {
                    this.closeModal();
                }
            }
        } catch (e){
            createFutureErrorRecord( {exceptionMessage: e.message ?? e.body.message, stackTrace: e.stack ?? e.body.stackTrace, lineNum: 0, errortype: 'Javascript', procname: 'vitalSubPage.handleSubmitVitalSection'}) ;                     
        } 
    }
    get acceptedFormats() {
        return ['.png', '.jpg', '.jpeg'];  //JPG, PNG
    }
    async getFiles()    {
    try {
        if (this.childSubPages === 'Contact') {
            let files =  await getAssociatedFiles ( { recordId: this.selectedRecordId });
            this.error = undefined;               
            this.uploadedProfileFile  = files ? {   name: files[0].Title, id: files[0].Id } : {};  ///just get the first one as that is the most recent uploaded file -- used for profile photos so we want the latest one                               
        }         
        else if (this.childSubPages === 'Identity' ) {     
            let files =  await getAssociatedFiles ( { recordId: this.selectedRecordId });       
            this.error = undefined;               
            this.listOfUploadedIdentityFiles = files ? files.map((aFile) => {
                return {    name: aFile.Title,  id: aFile.Id    }
            }) : [];                                     
        }        
    } catch (e){
        this.error = e;
        this.uploadedContactFile = undefined;
        this.listOfUploadedIdentityFiles  = undefined;
        createFutureErrorRecord( {exceptionMessage: e.message ?? e.body.message, stackTrace: e.stack ?? e.body.stackTrace, lineNum: 0, errortype: 'Javascript', procname: 'assetSubPage.getFiles'}) ;                    
        }
    }    
    handleFileDelete(event) {
        const index = event.detail.name;
        if (this.childSubPages !== 'Identity'){ // Should be the only sub-page where deletions can occur
            return;
        }
        const fileId = this.listOfUploadedIdentityFiles[index]?.id;
        if (fileId) {
            deleteFileAndDocument({ contentVersionId: fileId })
                .then(() => {
                    this.getFiles();                    
                    //this.showToast('Success', 'File deleted successfully!', 'success');
                })
                .catch(() => {
                    this.showToast('Error', 'Failed to delete file.', 'error');
                });
        } else {
            this.showToast('Success', 'File removed successfully!', 'success');
        }
    }    
    handleUploadFinished(evt){
        try {
            this.getFiles()  //will populate the identity file list and grab the most recent file upload mapped to a profile photo.  Once we have the profile photo, we need to add it to the contact
            .then(() => {
                if (this.childSubPages === 'Contact') {
                    getVersionDataUrl ({recordId : this.uploadedProfileFile.id})  //returns an URL referencing the photo
                    .then(result=>{
                        let acct = {};
                        acct['Id']=this.selectedRecordId  ;  //populated from the wire adapter but is known by the parent component already
                        acct['Photo_URL__c']=result;
                        updateAccount({ acc: acct }); // to bypass sharing rules  
                        const event = new CustomEvent('newprofilephoto', { //Event to be handled by VirtualAccountCreater to refresh the profile photo
                            detail: `${result}`,
                            bubbles: true // so it propagates to the grandparent component VirtualAccountCreater
                        });
                        this.dispatchEvent(event);                                            
                        }                                    
                    )              
                }
            });
        } catch (e){
            this.error = e;
            this.uploadedContactFile = undefined;
            this.uploadedIdentityFile  = undefined;
            createFutureErrorRecord( {exceptionMessage: e.message ?? e.body.message, stackTrace: e.stack ?? e.body.stackTrace, lineNum: 0, errortype: 'Javascript', procname: 'assetSubPage.handleUploadFinished'}) ;                    
        }                                                 
    }         
    /*
    checkForPhoneFields(field, value) {
        ['Phone', 'PersonMobilePhone','Social_Security_Number__c'].forEach((field) => {
            if (this.account[field] && (field === 'Phone' || field === 'PersonMobilePhone')) {
                if (field === 'Phone') {
                    this.account.Phone = value;
                } else {
                    this.account.PersonMobilePhone = value;
                }
            } else if (this.account[field] && field === 'Social_Security_Number__c') {
                this.runSSNMethods(field, this.account[field]);
            }
        });
    }
    */
    /*
    runPhoneMethod(field, value) {
        const phonePattern = /^(?:[+][\d\s\-\.\,\*\(\)]{10,15}|[\d\s\-\.\,\*\(\)]{10,14})$/;
            if (!phonePattern.test(value)) {
            console.warn('Invalid phone format:', value);
            if (field === 'Phone') {
                this.updatedPhone = value; 
            } else {
                this.updatedPersonMobilePhone = value;
            }
            return;
        }
        const cleaned = ('' + value).replace(/\D/g, '');
        const match = cleaned.match(/^(\d{3})(\d{3})(\d{4})$/); 
        if (field === 'Phone') {
            this.updatedPhone = match ? `(${match[1]}) ${match[2]}-${match[3]}` : value;
        } else {
            this.updatedPersonMobilePhone = match ? `(${match[1]}) ${match[2]}-${match[3]}` : value;
        }
    } */
    runSSNMethods(field, value) {
        const cleaned = ('' + value).replace(/\D/g, '');
        const match = cleaned.match(/^(\d{3})(\d{2})(\d{4})$/);
        this.updateSSNNumber = match ? `${match[1]}-${match[2]}-${match[3]}` : value;
    }
    closeModal () {
        this.isModalOpen = false;
        const event = new CustomEvent('submitchild', {
            detail: true
        });
        this.dispatchEvent(event);
    }
    validateEmail(value) {
        const emailRegex = /^[^\s@]+@[^\s@]+\.[^\s@]+$/;
        this.emailError = emailRegex.test(value) ? true : false;
        this.VitalChildValidation();
    }
    validatePhone(value) {
        const phonePattern = /^(?:[+][\d\s\-.,*()]{10,15}|[\d\s\-.,*()]{10,14})$/;
        if (!value) {
            this.phoneError = true;
        } else {
            this.phoneError = phonePattern.test(value) ? true : false;
        }
        this.VitalChildValidation();
    }
    validateNumber(value) {
        const numberPattern = /^[1-9]\d*$/;
        this.numberError = numberPattern.test(value) ? true : false;
        this.VitalChildValidation();
    }
    validateYearsOfCollege (value) {
        if ((!value) || (Number(value) >= 0 && Number(value) <= 20)) {
            this.yearsOfCollegeError = true;
        } else {
            this.yearsOfCollegeError = false;        
        }
        this.VitalChildValidation();
    }
    validateYearsOfGraduateSchool (value) {
        if ((!value) || (Number(value) >= 0 && Number(value) <= 20)) {
            this.yearsOfGraduateSchoolError = true;
        } else {
            this.yearsOfGraduateSchoolError = false;        
        }
        this.VitalChildValidation();
    }
    validateSocialSecurityNumber (value) {
        const socialPattern = /^\D*(\d\D*){9}$/;
        if (!value) {
            this.socialSecurityError = true;
        } else {
            this.socialSecurityError = socialPattern.test(value) ? true : false;
        }
        this.VitalChildValidation();
    }    
    /*
    validateMailingAddress () {
        if (this.account.PersonMailingCity && this.account.PersonMailingCountry && this.account.PersonMailingPostalCode && this.account.PersonMailingState && this.account.PersonMailingStreet) {
            this.isMalingAddress = true;
        } else {
            this.isMalingAddress = false;
        }
        this.VitalChildValidation();      
    }*/
    validateAdultsInHousehold(value) {
        if (Number(value) >= 0 && Number(value) <= 20) {
            this.adultsInHouseholdError = true;
        } else {
            this.adultsInHouseholdError = false;        
        }
        this.VitalChildValidation();
    }
    validateChildrenOfThisRelationship(value) {
        if (Number(value) >= 0 && Number(value) <= 20) {
            this.childrenOfThisRelationshipError = true;
        } else {
            this.childrenOfThisRelationshipError = false;        
        }
        this.VitalChildValidation();
    }
    VitalChildValidation () {
        let validation;
        if (this.emailError && this.isMalingAddress && this.phoneError && this.numberError && this.adultsInHouseholdError && this.childrenOfThisRelationshipError && this.yearsOfCollegeError && this.yearsOfGraduateSchoolError && this.socialSecurityError  ) {
            validation = false;
        } else {
            validation = true;
        }
        let value1 = [];
        value1.push({emailError: this.emailError, phoneError: this.phoneError, numberError: this.numberError, yearsOfCollegeError: this.yearsOfCollegeError, yearsOfGraduateSchoolError: this.yearsOfGraduateSchoolError, socialSecurityError: this.socialSecurityError, isMalingAddress: this.isMalingAddress, childrenOfThisRelationshipError: this.childrenOfThisRelationshipError});
        const event = new CustomEvent('vitalvalidationsubchild', {
            detail: {
                validation: validation,
                value: value1
            }           
        });
        this.dispatchEvent(event);
    }
}