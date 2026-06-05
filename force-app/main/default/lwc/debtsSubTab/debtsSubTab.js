import { LightningElement, api, track, wire } from 'lwc';
import getObjectNameById from '@salesforce/apex/VitalAccountController.getObjectNameById';
import debitLogo from '@salesforce/resourceUrl/debitLogo';
import { ShowToastEvent } from 'lightning/platformShowToastEvent';
import deleteFileAndDocument from '@salesforce/apex/FileUploadController.deleteFileAndDocument';
import handleDelete from '@salesforce/apex/ChildrenController.handleDelete';
import getAssociatedFiles from '@salesforce/apex/FileUploadController.getAssociatedFiles';
import { getRelatedListRecords } from 'lightning/uiRelatedListApi';
import creditCard from './creditCard.html';
import additionalDebts from './additionalDebts.html';
import {notifyRecordUpdateAvailable } from 'lightning/uiRecordApi';
import { getRecord } from 'lightning/uiRecordApi';
import { refreshApex } from '@salesforce/apex';
import createFutureErrorRecord from "@salesforce/apex/Utility.createFutureErrorRecord";

export default class DebtsSubTab extends LightningElement {
    @api childSubPages;
    @api pages;
    @api parentRecId;        // Parent Object Id Id to pass
    @api objectName;       // Object type Credit_Card__r or Debts1__r something else  - RelationshipName
    @api ciFormStatus;
    @track recordsData=[];
    @track recordsDataAdditional=[];
    @api childMatterActivity;
    @api queryFields;
    @track error;
    @api objectApiName;
    @track selectedRecordId = '';
    @track recordId = '';
    file;
    base;
    shouldHandleSuccess = false;
    @track account = {};
    additionalTemp;  // temporary object to hold additional debt data
    addCreditCard = false;
    addDebitCard = false;
    addDebts = false;
    tempObjectName = 'Credit_Card__r';
    debitLogoImg = debitLogo;
    isModalOpen = false;
    temp = false;
    uploadedFileName = '';
    uploadedDebitFileName = '';
    uploadedCreditFileName = '';
    @track listOfUploadedFileNames = [];
    @track isSameObject;
    // new 10/6
    currentField='';  //used to track the field currently being edited.
    addNewOrEditExistingRecord=false;  // to keep track when new or existing record is being edited...used to control commits to Salesforce
    isEditing=false;  //set to true once a form field has been updated    
    fromAccountCreation=false;  // we are creating a retirement account
    creationFromTabOut=false;    //record creation from a tab out
    sortBy = [];    

    @wire(getRelatedListRecords, {
        parentRecordId: '$parentRecId',       // Id of the account whose related list we need
        relatedListId: '$objectName',         // Dynamically switch between Credit_Card__c or Debt__c
        fields: '$queryFields',
        sortBy: '$sortBy',
        pageSize: 1000        
    })
    wiredRelatedListRecords(result) {
        const { error, data } = result;
        if (data) {
            this.error = undefined;
            this.recordsData = [...data.records]; 
            console.log('***inside recordsData',JSON.stringify(this.recordsData));          
        } else if (error) {
            this.error = error;
            this.recordsData = undefined;
        }
    }
    @wire(getRelatedListRecords, { //have to retrieve the additional debts separately since recordsData can't switch between the two object very quickly
        parentRecordId: '$parentRecId',
        relatedListId: 'Debts__r',
        fields: ['Debt__c.Id', 'Debt__c.Name', 'Debt__c.Marital_or_Separate_Property__c','Debt__c.Type__c','Debt__c.Balance__c','Debt__c.Monthly_Payment__c','Debt__c.Account_Number_Last_4__c'],
        sortBy: '$sortBy',
        pageSize: 1000          
    })
    wiredDebitRelatedListRecords(result) {
        const { error, data } = result;
        if (data) {
            this.error = undefined;
            this.recordsDataAdditional = [...data.records]; 
            console.log('***inside recordsDataAdditional',JSON.stringify(this.recordsDataAdditional));          
        } else if (error) {
            this.error = error;
            this.recordsData = undefined;
        }
    }
    connectedCallback(){
        this.recordsData=[];  //reset
        this.recordsDataAdditional=[];  //reset 
    }
    render () {
        console.log('SubPageName : ',this.childSubPages);
        if (this.sortBy.length==0 || (this.sortBy.length==1 && !this.sortBy[0].includes(this.objectApiName) ) ){
            this.sortBy =[this.objectApiName+'.Name'];        
        }         
        switch (this.childSubPages) {
            case 'Credit Cards':
                this.addDebitCard = false;
                return creditCard;
            case 'Additional Debts':           
                this.addCreditCard = false;
                return additionalDebts;
            default:
                return creditCard;
        }

    }
    handleAddCreditCard () {
        this.selectedRecordId = '';
        this.listOfUploadedFileNames=[];
        this.addCreditCard = true;
        this.addDebitCard = false;
        this.temp = false;        
    }
    handleCreditCellClick(event) {
        if (!this.childSubPages) {
            this.handleSaveChild();
            this.selectedRecordId = '';
        }
        this.selectedRecordId = '';
        this.temp = true;
        const recordId = event.currentTarget.dataset.id;
        console.log('recordId',recordId);
        this.objectApiName = event.currentTarget.dataset.field;
        this.selectedRecordId = recordId;
        this.getFiles();
        this.addCreditCard = true;
    }
    handleAddDebitCard () {
        this.temp = false;
        this.addDebitCard = true;
        this.listOfUploadedFileNames=[];
        this.selectedRecordId = '';
    }
    handleAddDebitCellClick(event) {
        if (!this.childSubPages) {
            this.handleSaveChild();
            this.selectedRecordId = '';
        }
        this.selectedRecordId = '';
        const recordId = event.currentTarget.dataset.id;
        this.objectApiName = event.currentTarget.dataset.field;
        this.selectedRecordId = recordId;
        this.getFiles();
        console.log('recordId =>'+recordId);
        console.log('this.selectedRecordId =>'+this.selectedRecordId);
        this.addDebitCard = true;
    }

    handleSaveChild () {
        const event = new CustomEvent('savechild', {
            detail: true
        });
        this.dispatchEvent(event);
    }
    /* 10/24 changes */
    get selectedRecordIdIsSet(){ //can't attach a file to a record if the record does not exist already
        if (!this.selectedRecordId || this.selectedRecordId===''){
            return false;
        } else {return true;}
    }  
    handleCreation(event) { //we want to create the credit card/additional debt after the user tabs out of the name field so that the file upload box appears.  Insert happens in handleOnChange
        if ((this.currentField==='' || this.currentField===event.target.fieldName) && !this.selectedRecordId) { //if it's the same field, just return
            this.currentField = event.target.fieldName; 
            this.fromAccountCreation=true;
            return;
        }
        this.handleOnChange(event);  //be sure to track changes
        //this.creationFromTabOut=true;
        //this.handleSubmitForm(event);
    }
    handleOnChange(event) { //whenever there is a change to a form field
    try {

        if (this.addNewOrEditExistingRecord){ // triggered from employment edit or add buttons which calls handleEmployeeNext even though no edits have been made
            this.addNewOrEditExistingRecord=false;              
            return;
        }
        this.setIsEditingTrue();  //fire an event so parent components know an edit was made
        if ( this.currentField!=='' && this.currentField!==event.target.fieldName && this.fromAccountCreation) { //We have tabbed out of the Name field and need to commit the record.
            this.currentField = '';  //reset
            this.fromAccountCreation=false;  //reset
            this.creationFromTabOut=true;
            this.handleSubmitForm(event);
        }
        console.log('input Change');
        } catch (error) {
            this.error = error;
            this.showToast('Error', error.message, 'error');
            this.disableButton=false;
            createFutureErrorRecord( {exceptionMessage: error.message ?? error.body.message, stackTrace: error.stack ?? error.body.stackTrace, lineNum: 0, errortype: 'Javascript', procname: 'debtsSubTab.handleOnChange'}) ;                     
        }             
    }    
    get acceptedFormats() {
        return ['.pdf', '.png', '.jpg', '.jpeg', '.csv', '.docx', '.xlsx', '.xlsm', '.xls'];  //JPG, PDF, CSV, DOCX, XLSX
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
            console.log('JSON.parse(JSON.stringify(event.detail.fields ))', JSON.parse(JSON.stringify(event.detail.fields )));                    
            this.setIsEditingFalse();  // fire an event so parent components know an submit was made and that menu navigation is allowed      
            this.selectedRecordId =  event.detail.id;       
            let insertedRecordFields=Object.assign(   {'Id': { displayValue:null, value: event.detail.id } } , JSON.parse(JSON.stringify(event.detail.fields ))  );  
            if (this.childSubPages==="Credit Cards") {
                let insertedRecord={apiName: "Credit_Card__c", childRelationships:{}, id: event.detail.id, fields: insertedRecordFields };  
                this.recordsData = this.recordsData.filter(row => row.id !== event.detail.id );  //since we will insert it again        
                this.recordsData=[...this.recordsData, insertedRecord];                
                console.log('this.recordsData  ', JSON.stringify(this.recordsData)); 
                if (this.creationFromTabOut!==true)   { //record creation from a tab out
                    this.handleCreditCancel(); //to close the edit window                                
                }
            } else if (this.childSubPages==="Additional Debts") {
                insertedRecordFields=Object.assign(   {'Id': { displayValue:null, value: event.detail.id } } , JSON.parse(JSON.stringify(this.additionalTemp ))  );   //the event does not contain all the fields required for display
                console.log('insertedRecordFields  ', JSON.stringify(insertedRecordFields));                  
                let insertedRecord={apiName: "Debt__c", childRelationships:{}, id: event.detail.id, fields: insertedRecordFields };
                this.recordsDataAdditional = this.recordsDataAdditional.filter(row => row.id !== event.detail.id );  //since we will insert it again        
                this.recordsDataAdditional=[...this.recordsDataAdditional, insertedRecord]; 
                console.log('this.recordsDataAdditional  ', JSON.stringify(this.recordsDataAdditional));
                if (this.creationFromTabOut!==true)   { //record creation from a tab out 
                    this.handleAdditionalCancel(); //to close the edit window
                }
            }
            this.creationFromTabOut=false;  //reset it
        } catch (error) {
                createFutureErrorRecord( {exceptionMessage: error.message ?? error.body.message, stackTrace: error.stack ?? error.body.stackTrace, lineNum: 0, errortype: 'Javascript', procname: 'debtsSubTab.handleSuccess'}) ;  
        }
    }  
    handleSubmitForm(event) {      
    try {
        /*
        if (this.isEditing) { //only if a change has been made to one of the form fields
            this.template.querySelector('lightning-record-edit-form').submit();  // sometimes the event is empty -- if the event is called from a parent component, then it will be empty here.
            this.setIsEditingFalse();     
        }        
        */
        if (this.isEditing) { //only if a change has been made to one of the form fields
            this.template.querySelector('lightning-record-edit-form').submit(event.detail.fields);  // sometimes the event is empty -- if the event is called from a parent component, then it will be empty here.
            this.setIsEditingFalse();     
        }
       /*
        if (!this.isEditing) { return; } //no edits to save
        const inputFields = this.template.querySelectorAll('lightning-input-field');  //have to query the input fields separately. Child_Resides_With__c
        const fieldsToSubmit = {};
        inputFields.forEach(field => {
            if (field.fieldName && field.value !== undefined) {
                fieldsToSubmit[field.fieldName] = field.value;
            }
        });
        this.template.querySelector('lightning-record-edit-form').submit(fieldsToSubmit);
        this.setIsEditingFalse;  //to handle the case when the submission is not successful 
        // */  
        } catch (error) {
            this.error = error;
            this.showToast('Error', error.message, 'error');
            this.disableButton=false;
            createFutureErrorRecord( {exceptionMessage: error.message ?? error.body.message, stackTrace: error.stack ?? error.body.stackTrace, lineNum: 0, errortype: 'Javascript', procname: 'debtsSubTab.handleSubmitForm'}) ;                     
        }             
    }         
    async handleSave(event) {
        try{
            const formatter = new Intl.NumberFormat('en-US', {
                style: 'currency',
                currency: 'USD',
                });
            this.isLoading = true;
            if (this.isEditing==true) { //we only want to save data if there has been a data change
                if (this.childSubPages==='Additional Debts'){ 
                    const inputFields = this.template.querySelectorAll('lightning-input-field');  //have to query the input fields separately. Child_Resides_With__c
                    this.additionalTemp = {};
                    inputFields.forEach(field => {
                        if ( (field.fieldName==='Balance__c' || field.fieldName==='Monthly_Payment__c') && (field.value!=undefined && field.value!=null)){
                            this.additionalTemp[field.fieldName]=Object.assign(    { displayValue: formatter.format(field.value), value: field.value } );  //convert the values into an object as that is what the field name references
                        } else {
                            this.additionalTemp[field.fieldName]=Object.assign(    { displayValue:null, value: field.value } );  //convert the values into an object as that is what the field name references                            
                        }

                    });
        
                }
                this.handleSubmitForm(event);  //performs the upsert by submitting the form --                         
            }
            this.setIsEditingFalse();  // reset it here instead of in handleSuccess because the form may go out of scope before handleSuccess is called.  VirtualAccountCreater then thinks that there are uncommitted changes.                 
            this.addCreditCard = false;
            this.addDebitCard = false;            
        } catch (error) {
            createFutureErrorRecord( {exceptionMessage: e.message ?? e.body.message, stackTrace: e.stack ?? e.body.stackTrace, lineNum: 0, errortype: 'Javascript', procname: 'debtsSubTab.handleSave'}) ;          
            this.showToast('Error', error.message, 'error');
        }
        setTimeout(() => {
            this.isLoading = false;
            }, 3000);        
    }    
    handleUploadFinished(event) { // to refresh the file list
        this.getFiles();
    }
    /* 10/24 changes */        
    async getFiles()    {
        try {            
            let files =  await getAssociatedFiles ( { recordId: this.selectedRecordId });
            this.error = undefined;
            this.listOfUploadedFileNames = files ? files.map((aFile) => {
                return {    name: aFile.Title,  id: aFile.Id    };
            }) : [];                       
        } catch (e){
            this.error = e;
            this.listOfUploadedFileNames = [];        
            createFutureErrorRecord( {exceptionMessage: e.message ?? e.body.message, stackTrace: e.stack ?? e.body.stackTrace, lineNum: 0, errortype: 'Javascript', procname: 'debtsSubTab.getFiles'}) ;                    
        }
    }  
    childErrorMsgGenerator(fields){
        let fieldData = fields;
        let errorMsg = ''
        fieldData.forEach(field =>{
            let fldName = field.fieldName == 'Name'?'Name':field.fieldName.replaceAll("_"," ").slice(0,-3);
            if((!field.value || field.value.trim?.() === '') && field.mandatory == true){
                errorMsg += 'Please check '+fldName+' field it is required.\n';   
            }
        });
        if(errorMsg){
            this.showToast('Error In Child Section Section', errorMsg, 'error');
        }
    }    
    showToast(title, message, variant) {
        const event = new ShowToastEvent({
            title: title,
            message: message,
            variant: variant,
        });
        this.dispatchEvent(event);
    }
    get AddDebitCardFalse(){
        if (this.addDebitCard==true) { return false;}
        return true;
    }
    get AddCreditCardFalse(){
        if (this.addCreditCard==true) { return false;}
        return true;        
    }
    handleAdditionalCancel () {
        this.addDebitCard = false;
        this.selectedRecordId = '';
    }
    
    handleCreditCancel () {
        this.addCreditCard = false;
        this.selectedRecordId = '';
    }
    closeModal () {
        console.log('closeModal Called')
        this.isModalOpen = false;
        //this.handleSaveChild();
        const event = new CustomEvent('submitchild', {
            detail: true
        });
        this.dispatchEvent(event);
    }        
    handleFileDelete(event) {
        const index = event.detail.name;
        const fileId = this.listOfUploadedFileNames[index]?.id;
        if (fileId) {
            deleteFileAndDocument({ contentVersionId: fileId })
                .then(() => {
                    this.getFiles();                    
                })
                .catch(() => {
                    this.showToast('Error', 'Failed to delete file.', 'error');
                });
        } else {
            this.showToast('Success', 'File removed successfully!', 'success');
        }        
    }
    handleDeleteChild(event) {
        try {
            const childRecordId = event.currentTarget.dataset.id;
            const childRecordObject = event.currentTarget.dataset.field;
            this.recordsData = this.recordsData.filter(item => item.id !== childRecordId);
            if (this.childSubPages==="Credit Cards") {
                this.recordsData = this.recordsData.filter(item => item.id !== childRecordId);          
            } else if (this.childSubPages==="Additional Debts") {
                this.recordsDataAdditional = this.recordsDataAdditional.filter(item => item.id !== childRecordId);
            }
            handleDelete({ recordId: childRecordId, objectName: childRecordObject })
                .then( () => {
                    notifyRecordUpdateAvailable([{ recordId: childRecordId }]);  // if this works at all
                    this.showToast('Success', 'Record deleted successfully', 'success');
                })
                .catch(error => {
                    this.showToast('Error', error.body, 'error');
                });
        } catch (e){
            this.error = e;
            this.listOfUploadedFileNames = [];        
            createFutureErrorRecord( {exceptionMessage: e.message ?? e.body.message, stackTrace: e.stack ?? e.body.stackTrace, lineNum: 0, errortype: 'Javascript', procname: 'debtsSubTab.handleDeleteChild'}) ;                    
        }            
    }
    handleSubmitDebit () {
        if (this.ciFormStatus === 'Open') {
            this.isModalOpen = true;
        } else {
            this.closeModal();
        }
    }
}