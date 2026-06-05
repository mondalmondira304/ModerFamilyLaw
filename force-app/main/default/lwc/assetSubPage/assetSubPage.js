import { LightningElement, api, wire, track } from 'lwc';
import assetLogo from '@salesforce/resourceUrl/assetLogo';
import handleDelete from '@salesforce/apex/ChildrenController.handleDelete';
import deleteFileAndDocument from '@salesforce/apex/FileUploadController.deleteFileAndDocument';
import getAssociatedFiles from '@salesforce/apex/FileUploadController.getAssociatedFiles';
import { ShowToastEvent } from 'lightning/platformShowToastEvent';
import {notifyRecordUpdateAvailable } from 'lightning/uiRecordApi';
import { refreshApex } from '@salesforce/apex';
import { getRelatedListRecords } from 'lightning/uiRelatedListApi';
import vehicles from './vehicles.html';
import realProperty from './realProperty.html';
import bankAccounts from './bankAccounts.html';
import investmentAccounts from './investmentAccounts.html';
import retirementAccounts from './retirementAccounts.html';
import lifeInsurance from './lifeInsurance.html';
import furnitureProperty from './furnitureProperty.html';
import additional from './additional.html';
import createFutureErrorRecord from "@salesforce/apex/Utility.createFutureErrorRecord";

export default class AssetSubPage extends LightningElement {
    @api childSubPages;
    @api pages;
    @api parentRecId;       
    @api objectName;     
    @api childMatterActivity;
    @api ciFormStatus;
    @api clientSubName;
    @api queryFields;
    @api objectApiName;
    @track error;
    @track recordsData=undefined;
    @track selectedRecordId = '';
    @track account = {};
    @track updatedRecordId = undefined;
    @track listOfUploadedFileNames = [];
    @track listOfUploadedRetirementFileNames = [];
    @track listOfUploadedBankFileNames = [];
    @track realPropertyCompulsoryFields = [
        'Name',
        'Property_City__c',
        'Zip_Code__c',
        'Property_State__c',
        'Marital_or_Separate__c',
    ];
    @track bankAccountCompulsoryFields = [
        'Name',
        'Account_Balance__c',
    ]
    @track lifeInsuranceCompulsoryFields = [
        'Name',
    ]
    @track furnitureCompulsoryFields = [
        'Name',
    ]
    file;
    base;
    hide = '';
    tempSubPage;
    relatedRecordWired;
    assetPage = 0;
    realStatePage = 0;
    bankAccountPage = 0;
    addVehicles = false;
    addRealState = false;
    addBankAccount = false;
    addBankAccountPage = false;
	addBalanceSheetPage = false;
    addInvestmentAccount = false;
    addRetirementAccount = false;
    addLifeInsuranceAccount = false;
    addFurnitureAccount = false;
    addAdditionalAccount = false;
    addVehiclePage = false;
    financingAndExpenses = false;
    valuation = false;
    addRealPropertyPage = false;
    addRealPropertyOwnerShipPage = false;
    addRealPropertyHOAPage = false;
    addRealPropertyMortagePage = false;
    addRealPropertyValuationPage = false;
    parentChildrenId = undefined;
    parentAccountrenId = undefined;
    parentChildrenField = undefined;
    addVehicleLabel = 'Add';
    addRealPropertyLabel = 'Add';
    addBankAccountsLabel = 'Add';
    addInvestmentAccountsLabel = 'Add';
    addRetirementAccountsLabel = 'Add';
    addLifeInsuranceLabel = 'Add';
    addFurnitureLabel = 'Add';
    addAdditionalLabel = 'Add';
    assetLogoImg = assetLogo;
    isModalOpen = false;
    shouldHandleSuccess = false;
    uploadedFileName = '';
    uploadedRetirementFileName = '';
    uploadedBankFileName = '';
    tempTab = 'Vehicles';
    // new 10/6
    currentField='';  //used to track the field currently being edited.
    addNewOrEditExistingRecord=false;  // to keep track when new or existing record is being edited...used to control commits to Salesforce
    isEditing=false;  //set to true once a form field has been updated    
    showData = false;  //whether or not there is any data to show
    dataObject=undefined ;  // the data object that we currently have data for
    fromRetirementAccount=false;  // we are creating a retirement account
    sortBy = [];

    @wire(getRelatedListRecords, {  
        parentRecordId: '$childMatterActivity',
        relatedListId: '$objectName',        
        fields: '$queryFields',
        sortBy: '$sortBy',
        pageSize: 1000
    })
    processResults(result) {
        this.showData = true; //always true
        this.relatedRecordWired = result;
        const { error, data } = result;
        if (data) {
            this.error = undefined;
            this.recordsData = [...data.records]; 
            this.dataObject=this.objectName;  //once the data is retrieved, set the dataObject
            console.log('***inside else recordsData',JSON.stringify(this.recordsData));
            this.showData = true;            
        } else if (error) {
            this.error = error;
            this.recordsData = undefined;
        }
    }
    get isVehicle(){
        if (this.dataObject==='Vehicles__r') { 
            return true;
        }
        return false;
    }
    get isAdditional(){
        if (this.dataObject==='Additional_Assets__r') { 
            return true;
        }
        return false;
    }
    get isBankAccount(){
        if (this.dataObject==='Bank_Investment_Accounts__r') { 
            return true;
        }
        return false;
    }
    get isFurnitureProperty(){
        if (this.dataObject==='Furniture_Personal_Property__r') { 
            return true;
        }
        return false;
    }       
    get isInvestmentAccount(){
        if (this.dataObject==='Investment_Account__r') { 
            return true;
        }
        return false;
    }            
    get isLifeInsurance(){
        if (this.dataObject==='Life_Insurance__r') { 
            return true;
        }
        return false;
    }
    get isRealProperty(){
        if (this.dataObject==='Housing__r') { 
            return true;
        }
        return false;
    }        
    get isRetirementAccount(){
        if (this.dataObject==='Retirement_Accounts__r') { 
            return true;
        }
        return false;
    }         
    /*connectedCallback() {            
    }*/
    render () {
        console.log('render');
        this.selectedValue();
        if (this.sortBy.length==0 || (this.sortBy.length==1 && !this.sortBy[0].includes(this.objectApiName) ) ){
            this.sortBy =[this.objectApiName+'.Name'];        
        }     
        switch (this.childSubPages) {
            case 'Vehicles':
                return vehicles;
            case 'Real Property':
                return realProperty;
            case 'Bank Accounts':
                return bankAccounts;
            case 'Investment Accounts':
                return investmentAccounts;
            case 'Retirement Accounts':
                return retirementAccounts;
            case 'Life Insurance':
                return lifeInsurance;
            case 'Furniture/Personal Property':
                return furnitureProperty;
            case 'Additional':
                return additional;
            default:
                return vehicles;
        }
    }
    selectedValue () {
        if (this.tempSubPage !== this.childSubPages) {
            this.tempSubPage = this.childSubPages;
            this.selectedRecordId = '';
        }
        return '';
    }
    get manageVehiclesPreviousButtons () {
        if (this.assetPage > 1) {
            return true;
        }
        return false;
    }
    get manageVehiclesNextButtons () {
        if (this.assetPage === 0 && !this.addVehicles) {
            return false;
        }
        return true;
    }
    get manageVehiclesNextButtons1 () {
        if (this.assetPage !== 3 && this.addVehicles) {
            return true;
        }
        return false;
    }
    get manageVehiclesSaveButtons () {
        if (this.assetPage === 3) {
            return true;
        }
        return false;
    }
    get manageRealStatePreviousButtons () {
        if (this.realStatePage > 1) {
            return true;
        }
        return false;
    }
    get manageRealStateNextButtons () {
        if (this.realStatePage === 0 && !this.addRealState) {
            return false;
        }
        return true;
    }
    get manageRealStateNextButtons1 () {
        if (this.realStatePage !== 5 && this.addRealState) {
            return true;
        }
        return false;
    }
    get manageRealStateSaveButtons () {
        if (this.realStatePage === 5) {
            return true;
        }
        return false;
    }
    get manageBankAccountPreviousButtons () {
        if (this.bankAccountPage > 1) {
            return true;
        }
        return false;
    }
    get manageBankAccountNextButtons () {
        if (this.bankAccountPage === 0 && !this.addBankAccount) {
            return false;
        }
        return true;
    }
    get manageBankAccountNextButtons1 () {
        if (this.bankAccountPage !== 2 && this.addBankAccount) {
            return true;
        }
        return false;
    }
    get manageBankAccountButtons () {
        if (this.bankAccountPage === 2) {
            return true;
        }
        return false;
    }
    get hideFirstPage () {
        if (!this.addBankAccount) {
            return 'display: none';
        } else if (this.addBalanceSheetPage) {
            return 'display: none';
        }
        return 'display: block';
    }
    get hideSecondPage () {
        if (this.addBalanceSheetPage) {
            return 'display: block';
        }
        return 'display: none';
    }
    get updateRecordId () {
        if (this.objectApiName !== this.isSameObject) {
            this.selectedRecordId = '';
        }
        return '';
    }
    get acceptedFormats() {
        return ['.pdf', '.png', '.jpg', '.jpeg', '.csv', '.docx', '.xlsx', '.xlsm', '.xls'];  //JPG, PDF, CSV, DOCX, XLSX
    }    
    handleSaveChild () {        
        const event = new CustomEvent('savechild', {
            detail: true
        });
        this.dispatchEvent(event);
    }
    handleAssetNext (event) {
       try {
            this.currentField='';  //reset for handleOnChange
            this.handleSubmitForm(event);  //to save any data on the last field from the current screen      
            if (this.assetPage < 4) {
                this.assetPage++;
            }            
            if (this.childSubPages === 'Vehicles') {
                this.addVehiclePage = this.assetPage === 1;
                this.financingAndExpenses = this.assetPage === 2;
                this.valuation = this.assetPage === 3;
            }
            if (this.assetPage === 4) {
                this.handleSaveChild();
            }
        } catch (e){
            createFutureErrorRecord( {exceptionMessage: e.message ?? e.body.message, stackTrace: e.stack ?? e.body.stackTrace, lineNum: 0, errortype: 'Javascript', procname: 'assetSubTab.handleAssetNext'}) ;                     
        }            
    }
    handleAssetPrevious (event) {
        try {
            this.currentField='';  //reset for handleOnChange
            this.handleSubmitForm(event);  //to save any data on the last field from the current screen      
            this.assetPage = this.assetPage - 1;
            if (this.childSubPages === 'Vehicles') {
                this.addVehiclePage = this.assetPage === 1;
                this.financingAndExpenses = this.assetPage === 2;
                this.valuation = this.assetPage === 3;
            }
        } catch (e){
            createFutureErrorRecord( {exceptionMessage: e.message ?? e.body.message, stackTrace: e.stack ?? e.body.stackTrace, lineNum: 0, errortype: 'Javascript', procname: 'assetSubTab.handleAssetPrevious'}) ;                     
        }         
    }    
    assetErrorHandler(fields){
        let fieldData = fields;
        let errorMsg = ''
        fieldData.forEach(field =>{
            let fldName;
            if(this.childSubPages === 'Life Insurance'){
                 fldName = 'Carrier';
            } else {
                fldName = field.fieldName == 'Name'?'Name':field.fieldName.replaceAll("_"," ").slice(0,-3);
            }
            if((!field.value || field.value.trim?.() === '') && field.mandatory == true){
                errorMsg += 'Please check '+fldName+' field it is required.\n';
                
            }
        });
        if(errorMsg){
            this.showToast('Error In Asset Section ', errorMsg, 'error');
        }
    }
    handleAddVehicles () {
        this.selectedRecordId = '';
        this.addVehicles = true;
        this.addVehicleLabel = 'Add';
        this.handleAssetNext();
    }
    handleVehiclesCellClick(event) {
        this.selectedRecordId = '';
        this.year = this.recordsData[event.currentTarget.dataset.index].Year__c;
        this.make = this.recordsData[event.currentTarget.dataset.index].Make__c;
        this.addVehicleLabel = 'Update';
        if (!this.childSubPages) {
            this.handleSaveChild();
            this.selectedRecordId = '';
        }
        const recordId = event.currentTarget.dataset.id;
        this.objectApiName = event.currentTarget.dataset.field;
        this.selectedRecordId = recordId;
        this.addVehicles = true;
        console.log('this.selectedRecordId handleVehiclesCellClick=>',this.selectedRecordId);
        
        setTimeout(() => {
            this.handleAssetNext();
        }, 1000);
    }
    handleAddInvestment () {
        this.selectedRecordId = '';
        this.addInvestmentAccount = true;
        this.addInvestmentAccountsLabel = 'Add';
    }
    handleInvestmentCellClick(event) {
        this.selectedRecordId = '';
        this.addInvestmentAccountsLabel = 'Update';
        if (!this.childSubPages) {
            this.handleSaveChild();
            this.selectedRecordId = '';
        }
        const recordId = event.currentTarget.dataset.id;
        this.objectApiName = event.currentTarget.dataset.field;
        this.selectedRecordId = recordId;
        this.addInvestmentAccount = true;
    }
    handleRetirementVehicles () {
        this.selectedRecordId = '';
        this.listOfUploadedRetirementFileNames = [];
        this.addRetirementAccount = true;
        this.addRetirementAccountsLabel = 'Add';
    }
    handleRetirementCellClick(event) {
        this.selectedRecordId = '';
        this.listOfUploadedRetirementFileNames = [];
        this.addRetirementAccountsLabel = 'Update';
        if (!this.childSubPages) {
            this.handleSaveChild();
            this.selectedRecordId = '';
        }
        const recordId = event.currentTarget.dataset.id;
        this.objectApiName = event.currentTarget.dataset.field;
        this.selectedRecordId = recordId;
        this.addRetirementAccount = true;
        this.getFiles();
    }
    handleAddInsurance () {
        this.selectedRecordId = '';
        this.addLifeInsuranceLabel = 'Add';
        this.addLifeInsuranceAccount = true;
    }
    handleInsuranceCellClick(event) {
        this.selectedRecordId = '';
        this.addLifeInsuranceLabel = 'Update';
        if (!this.childSubPages) {
            this.handleSaveChild();
            this.selectedRecordId = '';
        }
        const recordId = event.currentTarget.dataset.id;
        this.objectApiName = event.currentTarget.dataset.field;
        this.selectedRecordId = recordId;
        this.addLifeInsuranceAccount = true;
    }
    handleAddFurniture () {
        this.selectedRecordId = '';
        this.addFurnitureLabel = 'Add';
        this.addFurnitureAccount = true;
    }
    handleFurnitureCellClick(event) {
        this.selectedRecordId = '';
        this.addFurnitureLabel = 'Update';
        if (!this.childSubPages) {
            this.handleSaveChild();
            this.selectedRecordId = '';
        }
        const recordId = event.currentTarget.dataset.id;
        this.objectApiName = event.currentTarget.dataset.field;
        this.selectedRecordId = recordId;
        this.addFurnitureAccount = true;
    }
    handleAddAdditional () {
        this.selectedRecordId = '';
        this.addAdditionalLabel = 'Add';
        this.addAdditionalAccount = true;
    }
    handleAdditionalCellClick(event) {
        this.selectedRecordId = '';
        this.addAdditionalLabel = 'Update';
        if (!this.childSubPages) {
            this.handleSaveChild();
        }
        const recordId = event.currentTarget.dataset.id;
        this.objectApiName = event.currentTarget.dataset.field;
        this.selectedRecordId = recordId;
        this.addAdditionalAccount = true;
    }
    handleRealStateNext (event) {
        const inputFields = this.template.querySelectorAll('lightning-input-field');
        let fieldData = [];
        let isValid = true;
        inputFields.forEach(field => {            
            fieldData.push({
                fieldName: field.fieldName,
                value: field.value,
                mandatory:this.realPropertyCompulsoryFields.includes(field.fieldName)
            });
            let mandatoryOrNot = this.realPropertyCompulsoryFields.includes(field.fieldName);
            if ((!field.value || field.value.trim?.() === '') && mandatoryOrNot) {
                isValid = false;
            }          
        });
        if(!isValid){
            this.assetErrorHandler(fieldData);
        }else{
            this.nextSubmitScreen=true;  //if this function is called from a "Next" or "Submit" button, be sure to commit the record
            this.currentField='';  //reset for handleOnChange
            this.handleSubmitForm(event);  //to save any data on the last field from the current screen                
            if (this.realStatePage < 6) {
                this.realStatePage++;
            }
            if (this.childSubPages === 'Real Property') {
                this.addRealPropertyPage = this.realStatePage === 1;
                this.addRealPropertyOwnerShipPage = this.realStatePage === 2;
                this.addRealPropertyHOAPage = this.realStatePage === 3;
                this.addRealPropertyMortagePage = this.realStatePage === 4;
                this.addRealPropertyValuationPage = this.realStatePage === 5;
            }
            if (this.realStatePage === 6) {
                this.handleSaveChild();
            }
        }
    }
    handleRealStatePrevious (event) {
        this.nextSubmitScreen=true;  //if this function is called from a "Next" or "Submit" button, be sure to commit the record
        this.currentField='';  //reset for handleOnChange
        this.handleSubmitForm(event);  //to save any data on the last field from the current screen     
        this.realStatePage = this.realStatePage - 1;
        if (this.childSubPages === 'Real Property') {
            this.addRealPropertyPage = this.realStatePage === 1;
            this.addRealPropertyOwnerShipPage = this.realStatePage === 2;
            this.addRealPropertyHOAPage = this.realStatePage === 3;
            this.addRealPropertyMortagePage = this.realStatePage === 4;
            this.addRealPropertyValuationPage = this.realStatePage === 5;
        }
    }
    handleRealStateVehicles () {
        this.selectedRecordId = '';
        this.addRealState = true;
        this.addRealPropertyLabel = 'Add';
        this.handleRealStateNext();
    }
    handleRealStateCellClick(event) {
        this.selectedRecordId = '';
        this.addRealPropertyLabel = 'Update';
        if (!this.childSubPages) {
            this.handleSaveChild();
        }
        this.address = this.recordsData[event.currentTarget.dataset.index].Name;
        const recordId = event.currentTarget.dataset.id;
        this.objectApiName = event.currentTarget.dataset.field;
        this.selectedRecordId = recordId;
        this.addRealState = true;
        setTimeout(() => {
            this.handleRealStateNext();
        }, 1000);
    }
    handleBankAccountNext (event) {
        const inputFields = this.template.querySelectorAll('lightning-input-field');
        let fieldData = [];
        let isValid = true;
        inputFields.forEach(field => {            
            fieldData.push({
                fieldName: field.fieldName,
                value: field.value,
                mandatory:this.bankAccountCompulsoryFields.includes(field.fieldName)
            });
            let mandatoryOrNot = this.bankAccountCompulsoryFields.includes(field.fieldName);
            if ((!field.value || field.value.trim?.() === '') && mandatoryOrNot) {
                isValid = false;
            }            
        });
        if(!isValid){
            this.assetErrorHandler(fieldData);
        }else{
            this.nextSubmitScreen=true;  //if this function is called from a "Next" or "Submit" button, be sure to commit the record
            this.currentField='';  //reset for handleOnChange
            this.handleSubmitForm(event);  //to save any data on the last field from the current screen                                
            this.shouldHandleSuccess = false;
            if (this.bankAccountPage < 3) {
                this.bankAccountPage++;
            }
            if (this.childSubPages === 'Bank Accounts') {
                this.addBankAccountPage = this.bankAccountPage === 1;
                this.addBalanceSheetPage = this.bankAccountPage === 2;
            }
            if (this.addBankAccountPage) {
                this.hide = 'display: none';
            } else {
                this.hide = 'display: block';
            }
            if (this.bankAccountPage === 3) {
                this.handleSaveChild();
            }
        }
    }
    handleBankAccountPrevious (event) {
        this.nextSubmitScreen=true;  //if this function is called from a "Next" or "Submit" button, be sure to commit the record
        this.currentField='';  //reset for handleOnChange
        this.handleSubmitForm(event);  //to save any data on the last field from the current screen                              
        this.bankAccountPage = this.bankAccountPage - 1;
        if (this.childSubPages === 'Bank Accounts') {
            this.addBankAccountPage = this.bankAccountPage === 1;
            this.addBalanceSheetPage = this.bankAccountPage === 2;
        }
    }
    handleBankAccountVehicles () {
        this.selectedRecordId = '';
        this.listOfUploadedBankFileNames = [];
        this.addBankAccount = true;
        this.addBankAccountsLabel = 'Add';
        this.handleBankAccountNext();
    }
    handleBankAccountCellClick(event) {
        this.selectedRecordId = '';
        this.listOfUploadedBankFileNames = [];
        this.addBankAccountsLabel = 'Update';
        if (!this.childSubPages) {
            this.handleSaveChild();
        }
        this.bankAccountName = this.recordsData[event.currentTarget.dataset.index].Name;
        const recordId = event.currentTarget.dataset.id;
        this.objectApiName = event.currentTarget.dataset.field;
        this.selectedRecordId = recordId;
        this.addBankAccount = true;
        this.getFiles();
        setTimeout(() => {
            this.handleBankAccountNext();
        }, 1000);
    }
    handleRetirementAccountCreation(event) { //we want to create the retirement account after the user tabs out of the name field so that the file upload box appears.  Insert happens in handleOnChange
        if ((this.currentField==='' || this.currentField===event.target.fieldName) && !this.selectedRecordId) { //if it's the same field, just return
            this.currentField = event.target.fieldName; 
            this.fromRetirementAccount=true;
            return;
        }
        this.handleOnChange(event);  //be sure to track changes
        this.handleSubmitForm(event);
    }
    handleOnChange(event) { //whenever there is a change to a form field
    try {

        if (this.addNewOrEditExistingRecord){ // triggered from employment edit or add buttons which calls handleEmployeeNext even though no edits have been made
            this.addNewOrEditExistingRecord=false;              
            return;
        }
        this.setIsEditingTrue();  //fire an event so parent components know an edit was made
        if ( this.currentField!=='' && this.currentField!==event.target.fieldName && this.fromRetirementAccount) { //special case for the retirement account subpage.  We have tabbed out of the Name field and need to commit the record.
            this.currentField = '';  //reset
            this.fromRetirementAccount=false;
            this.handleSubmitForm(event);
        }
        console.log('input Change');
        } catch (error) {
            this.error = error;
            this.showToast('Error', error.message, 'error');
            this.disableButton=false;
            createFutureErrorRecord( {exceptionMessage: error.message ?? error.body.message, stackTrace: error.stack ?? error.body.stackTrace, lineNum: 0, errortype: 'Javascript', procname: 'assetSubPage.handleOnChange'}) ;                     
        }             
    }    
    async handleSave(event) {
        this.isLoading = true;
        //if (event.detail) { //we only want to save data if there has been a data change
            this.handleSubmitForm(event);  //performs the upsert by submitting the form -- 
        //}            
        this.setIsEditingFalse();  // reset it here instead of in handleSuccess because the form may go out of scope before handleSuccess is called.  VirtualAccountCreater then thinks that there are uncommitted changes.                
            try {
            if (this.childSubPages === 'Vehicles') {
                this.assetPage = 0;
                this.addVehiclePage = false;
                this.financingAndExpenses = false;
                this.valuation = false;
                this.addVehicles = false;
            } else if (this.childSubPages === 'Real Property') {
                this.addRealPropertyPage = false;
                this.addRealPropertyOwnerShipPage = false;
                this.addRealPropertyHOAPage = false;
                this.addRealPropertyMortagePage = false;
                this.addRealPropertyValuationPage = false;
                this.addRealState = false;
                this.realStatePage = 0;
            } else if (this.childSubPages === 'Bank Accounts') {
                this.addBankAccount = false;
                this.addBankAccountPage = false;
                this.addBalanceSheetPage = false;
                this.bankAccountPage = 0;
            } else if (this.childSubPages === 'Investment Accounts') {
                this.addInvestmentAccount = false;
            } else if (this.childSubPages === 'Retirement Accounts') {
                this.addRetirementAccount = false;
            } else if (this.childSubPages === 'Life Insurance') {
                this.addLifeInsuranceAccount = false;
            } else if (this.childSubPages === 'Furniture/Personal Property') {
                this.addFurnitureAccount = false;
            } else {
                this.addAdditionalAccount = false;
            }                      
            ;                
            } catch (error) {
                this.error = error;
                this.showToast('Error', error.message, 'error');
            }
            setTimeout(() => {
                this.isLoading = false;
            }, 1000);        
    }     

    showToast(title, message, variant) {
        const event = new ShowToastEvent({
            title: title,
            message: message,
            variant: variant,
        });
        this.dispatchEvent(event);
    }
    handleCancelVehicles () {
        this.addVehicles = false;
    }
    handleDeleteChild(event) {
        const childRecordId = event.currentTarget.dataset.id;
        const childRecordObject = event.currentTarget.dataset.field;
        this.recordsData = this.recordsData.filter(item => item.id !== childRecordId);
        handleDelete({ recordId: childRecordId, objectName: childRecordObject })
            .then( () => {
                notifyRecordUpdateAvailable([{ recordId: childRecordId }]);  // if this works at all
                refreshApex(this.relatedRecordWired);
                this.showToast('Success', 'Record deleted successfully', 'success');
            })
            .catch(error => {
                this.showToast('Error', error.body, 'error');
            });
    }
    handleSubmitAsset () {
        if (this.ciFormStatus === 'Open') {
            this.isModalOpen = true;
        } else {
            this.closeModal();
        }
    }
    closeModal () {
        this.isModalOpen = false;
        this.handleSaveChild();
        const event = new CustomEvent('submitchild', {
            detail: true
        });
        this.dispatchEvent(event);
    }
    get selectedRecordIdIsSet(){ //can't attach a file to a record if the record does not exist already
        if (!this.selectedRecordId || this.selectedRecordId===''){
            return false;
        } else {return true;}
    }    
    handleFileDelete(event) {
        const index = event.detail.name;
        const isRetirement = this.childSubPages === 'Retirement Accounts';
        const fileList = isRetirement ? this.listOfUploadedRetirementFileNames : this.listOfUploadedBankFileNames;
        const fileId = fileList[index]?.id;
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
    handleUploadFinished(event){ // to refresh the file list
        this.getFiles();
    }
    async getFiles()    {
        try {
            if (this.childSubPages === 'Bank Accounts' || this.childSubPages === 'Retirement Accounts') {        //TODO what about the other childSubPages
                let files =  await getAssociatedFiles ( { recordId: this.selectedRecordId });
                this.error = undefined;
                if (this.childSubPages === 'Bank Accounts') {
                    this.listOfUploadedBankFileNames = files ? files.map((aFile) => {
                        return {    name: aFile.Title,  id: aFile.Id    }
                    }) : [];                    
                } else if (this.childSubPages === 'Retirement Accounts')    {
                    this.listOfUploadedRetirementFileNames = files ? files.map((aFile) => { 
                        return {    name: aFile.Title,  id: aFile.Id    };
                    }) : [];
                }            
            }
        } catch (e){
            this.error = e;
            this.uploadedTaxReturnFile = [];
            this.uploadedCurrentEmploymentFile = [];
            createFutureErrorRecord( {exceptionMessage: e.message ?? e.body.message, stackTrace: e.stack ?? e.body.stackTrace, lineNum: 0, errortype: 'Javascript', procname: 'assetSubPage.getFiles'}) ;                    
        }
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
            //this.setIsEditingFalse();  // fire an event so parent components know an submit was made and that menu navigation is allowed      commented 11/5
            this.selectedRecordId =  event.detail.id;       
            this.recordsData = this.recordsData.filter(row => row.id !== event.detail.id );  //since we will insert it again
            //let insertedRecordFields=Object.assign(    {'Id': { displayValue:null, value: event.detail.id } } , JSON.parse(JSON.stringify(event.detail.fields ))    );           
            let insertedRecordFields=Object.assign(   {'Id': { displayValue:null, value: event.detail.id } } , JSON.parse(JSON.stringify(event.detail.fields ))  );  
            let insertedRecord={apiName: "Vehicle__c", childRelationships:{}, id: event.detail.id, fields: insertedRecordFields };
            this.recordsData=[...this.recordsData, insertedRecord];
            console.log('this.recordsData  ', JSON.stringify(this.recordsData));          
        } catch (error) {
                createFutureErrorRecord( {exceptionMessage: error.message ?? error.body.message, stackTrace: error.stack ?? error.body.stackTrace, lineNum: 0, errortype: 'Javascript', procname: 'assetSubPage.handleSuccess'}) ;  
        }
    }    
    handleSubmitForm(event) {      
    try {
        if (this.isEditing) { //only if a change has been made to one of the form fields
            this.template.querySelector('lightning-record-edit-form').submit();  // will call the onSuccess event handled by handleSuccess
            this.setIsEditingFalse();     
        }
        } catch (error) {
            this.error = error;
            this.showToast('Error', error.message, 'error');
            this.disableButton=false;
            createFutureErrorRecord( {exceptionMessage: error.message ?? error.body.message, stackTrace: error.stack ?? error.body.stackTrace, lineNum: 0, errortype: 'Javascript', procname: 'assetSubPage.handleSubmitForm'}) ;                     
        }             
    }   
}