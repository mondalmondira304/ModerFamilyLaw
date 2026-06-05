import { LightningElement, api, track, wire } from 'lwc';
import updateRecordDetail from '@salesforce/apex/VitalAccountController.updateRecordDetail';
import getAssociatedFiles from '@salesforce/apex/FileUploadController.getAssociatedFiles';
import gettingEmployeePhone from '@salesforce/apex/VitalAccountController.gettingEmployeePhone';
import { ShowToastEvent } from 'lightning/platformShowToastEvent';
import {getRecordNotifyChange } from 'lightning/uiRecordApi';
import incomeLogo from '@salesforce/resourceUrl/incomeLogo';
import handleDelete from '@salesforce/apex/ChildrenController.handleDelete';
import getOtherIncomeData  from '@salesforce/apex/ChildrenController.getOtherIncomeData';
import getTaxData from '@salesforce/apex/ChildrenController.getTaxData';
import getEmploymentData from '@salesforce/apex/ChildrenController.getEmploymentData';
import { refreshApex } from '@salesforce/apex';
import deleteFileAndDocument from '@salesforce/apex/FileUploadController.deleteFileAndDocument';
import { getRelatedListRecords } from 'lightning/uiRelatedListApi';
import { notifyRecordUpdateAvailable } from 'lightning/uiRecordApi';
import currentEmployment from './currentEmployment.html';
import currentSelfEmployment from './currentSelfEmployment.html';
import previousEmployment from './previousEmployment.html';
import incomeFromBenefitsEmployment from './incomeFromBenefitsEmployment.html';
import supportIncome from './supportIncome.html';
import investmentIncome from './investmentIncome.html';
import incomeFromTrusts from './incomeFromTrusts.html';
import rentalIncome from './rentalIncome.html';
import otherIncome from './otherIncome.html';
import taxReturns from './taxReturns.html';
import createFutureErrorRecord from "@salesforce/apex/Utility.createFutureErrorRecord";
const map = new Map();
export default class IncomeSubTab extends LightningElement {
    @api childSubPages;
    @api pages;
    @api parentRecId;        
    @api objectName;       
    @api ciFormStatus;
    @api childMatterActivity;
    tempSubPage;
    shouldHandleSuccess = false;
    @track recordsData;
    @api queryFields;
    @track error;
    @api objectApiName;
    otherIncomeRecordId = '';
    selectedRecordId = '';
    @track account = {};
    @track refreshKey = 0;
    @track recordDetail = { Id: undefined, Child_Name__c: undefined };
    disableButton=false;
    currentField='';  //used to track the field currently being edited.
    nextSubmitScreen=false; // if this function is called from a "Next" or "Submit" button, commit the record
    addNewOrEditExistingRecord=false;  // to keep track when new or existing record is being edited...used to control commits to Salesforce
    isEditing=false;  //set to true once a form field has been updated
    wiredResults; // run refreshApex against this
    @track previousData=[];  //previous employment data
    @track currentData=[];    //current employment data    
    addCreditCard = false;
    addDebts = false;
    addEmployment = false;
    employeePage = 0;
    addCurrentEmployment = false;
    addCurrentEmploymentIncome = false;
    addCurrentEmployer = false;
    addPreviousEmployer = false;
    visibleSelfEmployment = false;
    SelfEmployment = false;
    addTax = false;
    addcurrentEmploymentLabel = 'Add';
    addcurrentEmployment = 'Add';
    addpreviousEmployment = 'Add';
    addTaxLabel = 'Add';
    incomeLogoImg = incomeLogo;
    isModalOpen = false;
    updatedPhone;
    uploadedFileName = '';
    uploadedTaxReturnFileName = '';
    uploadedCurrentEmploymentFileName = '';
    @track uploadedTaxReturnFile = [];
    @track uploadedCurrentEmploymentFile = []
    recordId = '';
    @track compulsoryFields = [
        'Self_employment_number_of_years__c',
        'Employment_Name__c',
        'Year__c',
        'Joint_Filer__c',
    ];
    connectedCallback() {
        this.currentField='';  //reset
        this.HandleGetOtherIncomeData();           
        this.handleGetEmploymentData();
        this.handleGetTaxData();
    }
    render () {
        //console.log('render called');
        this.selectedValue;
        switch (this.childSubPages) {
            case 'Current Employment':
                return currentEmployment;
            case 'Current Self Employment':
                return currentSelfEmployment;
            case 'Previous Employment':
                return previousEmployment;
            case 'Income from Benefits':
                return incomeFromBenefitsEmployment;
            case 'Support Income':
                return supportIncome;
            case 'Investment Income':
                return investmentIncome;
            case 'Income from Trusts':
                return incomeFromTrusts;
            case 'Rental Income':
                return rentalIncome;
            case 'Other Income':
                return otherIncome;
            case 'Tax Returns':
                return taxReturns;
            default:
                return currentEmployment;
        }                
    }
    async HandleGetOtherIncomeData(){
        try {        
            let temp= await getOtherIncomeData({ matterId: this.childMatterActivity }        );
            this.otherIncomeRecordId = temp.Id;
        } catch (e){
            createFutureErrorRecord( {exceptionMessage: e.message ?? e.body.message, stackTrace: e.stack ?? e.body.stackTrace, lineNum: 0, errortype: 'Javascript', procname: 'incomeSubTab.HandleGetOtherIncomeData'}) ;                     
        }    
    }
    async handleGetEmploymentData(){
        let records= await getEmploymentData( { matterId: this.childMatterActivity } );
        this.currentData = records.filter(item => item.Date_Employment_Ended__c == null );
        this.previousData = records.filter(item => item.Date_Employment_Ended__c != null );
    }
    async handleGetTaxData(){
        this.recordsData= await getTaxData({ matterId: this.childMatterActivity }); 
    }

    get selectedValue () {
        if (this.childSubPages !== 'Current Self Employment' && this.tempSubPage !== this.childSubPages) {
            this.tempSubPage = this.childSubPages;
            this.selectedRecordId = '';
        }
        return '';
    }

    handleEmployeeNext (event) {
        try {
            this.nextSubmitScreen=true;  //if this function is called from a "Next" or "Submit" button, be sure to commit the record
            this.currentField='';  //reset for handleOnChange
            if (event){ //sometimes handleEmployeeNext is called from an add or edit record in which case there is no data to save
                this.handleSubmitForm(event);  //to save any data on the last field from the current screen        
            }
        if(this.SelfEmployment){
            if (this.employeePage < 5) {
                this.employeePage++;
            }
            if (this.childSubPages === 'Current Employment') {
                this.addCurrentEmployment = this.employeePage === 1;
                this.visibleSelfEmployment = this.employeePage === 2;
                this.addCurrentEmploymentIncome = this.employeePage === 3;
                this.addCurrentEmployer = this.employeePage === 4;
            }
            if (this.employeePage === 5) {
                this.handleSaveChild();
            }
        } else {
            if (this.employeePage < 4) {
                this.employeePage++;
            }
            if (this.childSubPages === 'Current Employment') {
                this.addCurrentEmployment = this.employeePage === 1;
                this.addCurrentEmploymentIncome = this.employeePage === 2;
                this.addCurrentEmployer = this.employeePage === 3;                
            }
            if (this.employeePage === 4) {
                this.handleSaveChild();
            }
        }       
        } catch (e){
            createFutureErrorRecord( {exceptionMessage: e.message ?? e.body.message, stackTrace: e.stack ?? e.body.stackTrace, lineNum: 0, errortype: 'Javascript', procname: 'incomeSubTab.handleEmployeeNext'}) ;                     
        }        
    }
    handleEmployeePrevious (event) {
        try {
        this.nextSubmitScreen=true;  //if this function is called from a "Next" or "Submit" button, be sure to commit the record
        this.currentField='';  //reset for handleOnChange
        if (event){ //only save the data if there has been an edit made
            this.handleSubmitForm(event);  //to save any data on the last field from the current screen                
        }
        this.employeePage = this.employeePage - 1;
        if (this.childSubPages === 'Current Employment') {
            if(this.SelfEmployment){
                this.addCurrentEmployment = this.employeePage === 1;
                this.visibleSelfEmployment = this.employeePage === 2;
                this.addCurrentEmploymentIncome = this.employeePage === 3;
                this.addCurrentEmployer = this.employeePage === 4;
            } else {
                this.addCurrentEmployment = this.employeePage === 1;
                this.addCurrentEmploymentIncome = this.employeePage === 2;
                this.addCurrentEmployer = this.employeePage === 3;
            }
        }
        } catch (e){
            createFutureErrorRecord( {exceptionMessage: e.message ?? e.body.message, stackTrace: e.stack ?? e.body.stackTrace, lineNum: 0, errortype: 'Javascript', procname: 'incomeSubTab.handleEmployeePrevious'}) ;                     
        }
    }
    get manageEmployeePreviousButtons () {
        if (this.employeePage > 1) {
            return true;
        }
        return false;
    }
    get manageEmployeeNextButtons () {
        if (this.employeePage === 0 && !this.addEmployment) {
            return false;
        }
        return true;
    }
    get manageEmployeeNextButtons1 () {
        if(this.SelfEmployment){
            if (this.employeePage !== 4 && this.addEmployment) {
            return true;
        }
        return false;
        } else {
            if (this.employeePage !== 3 && this.addEmployment) {
            return true;
        }
        return false;
        }
    }
    get manageEmployeeSaveButtons () {
        if(this.SelfEmployment){
            if (this.employeePage === 4) {
                return true;
            }
            return false;
        } else {
            if (this.employeePage === 3) {
                return true;
            }
            return false;
        }   
    }
    handleAddEmployment () {
        this.selectedRecordId = '';
        this.updatedPhone = '';
        this.uploadedCurrentEmploymentFile=[];
        this.SelfEmployment = false;
        this.addcurrentEmploymentLabel = 'Add'
        this.addEmployment = true;
        this.addNewOrEditExistingRecord=true;        
        this.handleEmployeeNext();  //this handles navigation as well as commits any changes
    }

    handleEmploymentCellClick(event) {
        try {
        this.addcurrentEmploymentLabel = 'Update'
        if (!this.childSubPages) {
            this.handleSaveChild();            
        }
        this.selectedRecordId = this.recordDetail.Id = this.recordId = event.currentTarget.dataset.id;
        this.objectApiName = event.currentTarget.dataset.field;
        this.getFiles();
        this.addEmployment = true;
        gettingEmployeePhone({recordDetail: this.selectedRecordId})
        .then(result => {
            const cleaned = ('' + result).replace(/\D/g, '');
            const match = cleaned.match(/^(\d{3})(\d{3})(\d{4})$/);
            this.updatedPhone = match ? `(${match[1]}) ${match[2]}-${match[3]}` : result.Employer_Phone__c;
            this.SelfEmployment = result?.Self_Employed_at_this_Job__c?true:false;
        })
        this.addNewOrEditExistingRecord=true;
        setTimeout(() => { this.handleEmployeeNext();  }, 1000); //this handles navigation as well as commits any changes
        } catch (e){
            createFutureErrorRecord( {exceptionMessage: e.message ?? e.body.message, stackTrace: e.stack ?? e.body.stackTrace, lineNum: 0, errortype: 'Javascript', procname: 'incomeSubTab.handleEmploymentCellClick'}) ;                     
        }
    }
    handleAddPreviousEmployer () {
        this.addpreviousEmployment = 'Add'
        this.addPreviousEmployer = true;
        this.selectedRecordId = '';
    }
    handlePreviousEmployerCellClick(event) {
        this.addpreviousEmployment = 'Update'
        if (!this.childSubPages) {
            this.handleSaveChild();            
        }
        this.selectedRecordId = '';
        const recordId = event.currentTarget.dataset.id;
        this.objectApiName = event.currentTarget.dataset.field;
        this.recordDetail.Id = recordId;
        this.selectedRecordId = recordId;
        this.addPreviousEmployer = true;
        this.recordId = recordId;
    }
    handleAddTax () {
        this.addTax = true;
        this.addTaxLabel = 'Add';
        this.selectedRecordId = '';
        this.recordDetail = { Id: undefined, Child_Name__c: undefined };
        this.uploadedTaxReturnFile = [];
    }
    handleTaxCellClick(event) {
        this.addTaxLabel = 'Update';
        if (!this.childSubPages) {
            this.handleSaveChild();           
        }
        this.selectedRecordId = '';
        this.uploadedTaxReturnFile = [];
        this.recordDetail = { Id: undefined, Child_Name__c: undefined };    
        const recordId = event.currentTarget.dataset.id;
        this.objectApiName = event.currentTarget.dataset.field;
        this.recordDetail.Id = recordId;
        this.selectedRecordId = recordId;     
        this.getFiles();     
        this.addTax = true;
        this.recordId = recordId;
    }
    handleSaveChild () { //event propagates back to virtualAccountCreater
        this.SelfEmployment= false;
        const event = new CustomEvent('savechild', {
            detail: true
        });
        this.dispatchEvent(event);
    }
    
    checkForPhoneFields() {
        try {
        ['Employer_Phone__c'].forEach((field) => {
            if (this.recordDetail[field] && (field === 'Employer_Phone__c')) {
                this.runPhoneMethod(field, this.recordDetail[field]);
            }
        });
        } catch (e){
            createFutureErrorRecord( {exceptionMessage: e.message ?? e.body.message, stackTrace: e.stack ?? e.body.stackTrace, lineNum: 0, errortype: 'Javascript', procname: 'incomeSubTab.handleEmploymentCellClick'}) ;                     
        }
    }
    runPhoneMethod(field, value) {
        const cleaned = ('' + value).replace(/\D/g, '');
        const match = cleaned.match(/^(\d{3})(\d{3})(\d{4})$/);
        if (field === 'Employer_Phone__c') {
            this.updatedPhone = match ? `(${match[1]}) ${match[2]}-${match[3]}` : value;
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
    async handleSave(event) { 
        try {
            this.nextSubmitScreen=true;  //if this function is called from a "Next" or "Submit" button, be sure to commit the record regardless if the user has tabbed out from a field
            if (event.detail) { //we only want to save data if there has been a data change
                this.handleSubmitForm(event);  //performs the upsert by submitting the form -- 
            }
            //Something is preventing the form submit from completing successfully on the last of the income screens.  Maybe the form goes out of scope before the successHandler can fire.  run setIsEditingFalse().            
            this.setIsEditingFalse();  // reset it here instead of in handleSuccess because the form may go out of scope before handleSuccess is called.  VirtualAccountCreater then thinks that there are uncommitted changes.
            this.currentField='';  //reset for handleOnChange

            if (this.childSubPages === 'Current Employment') {
                this.addCurrentEmployment = false;
                this.addCurrentEmploymentIncome = false;
                this.addCurrentEmployer = false;
                this.addEmployment = false;
                this.employeePage = 0;
                this.manageEmployeeNextButtons;

            } else if (this.childSubPages === 'Current Self Employment') {

            } else if (this.childSubPages === 'Previous Employment') {
                this.addPreviousEmployer = false;
                this.manageEmployeeNextButtons;
            } else if (this.childSubPages === 'Income from Benefits') {
                this.handleSaveChild();
            } else if (this.childSubPages === 'Support Income') {
                this.handleSaveChild();
            } else if (this.childSubPages === 'Investment Income') {
                this.handleSaveChild();
            } else if (this.childSubPages === 'Income from Trusts') {
                this.handleSaveChild();
            } else if (this.childSubPages === 'Rental Income') {
                this.handleSaveChild();
            } else if (this.childSubPages === 'Other Income') {
                this.handleSaveChild();
            } else if (this.childSubPages === 'Tax Returns') {                                
                this.addTax = false;                        
            } else {
                this.recordDetail = {};
            }
            this.recordDetail = { Id: undefined, Child_Name__c: undefined };
            this.selectedRecordId = '';
            this.recordId = '';
                        
            setTimeout(() => {
                //this.isLoading = false;
                this.disableButton=false;
            }, 3000);        
        } catch (e){
            createFutureErrorRecord( {exceptionMessage: e.message ?? e.body.message, stackTrace: e.stack ?? e.body.stackTrace, lineNum: 0, errortype: 'Javascript', procname: 'incomeSubTab.handleSave'}) ;                     
        }  
    }                               

    get selectedRecordIdIsSet(){ //can't attach a file to a record if the record does not exist already
        if (!this.selectedRecordId || this.selectedRecordId===''){
            return false;
        } else {return true;}
    }                

    handleOnChange(event) { //whenever there is a change to a form field
    try {
        if (this.addNewOrEditExistingRecord){ // triggered from employment edit or add buttons which calls handleEmployeeNext even though no edits have been made
            this.addNewOrEditExistingRecord=false;              
            return;
        }
        /*if ((this.currentField==='' || this.currentField===event.target.fieldName) && !this.nextSubmitScreen ) { //if this function is called from a "Next" or "Submit" button
            this.currentField = event.target.fieldName; 
            return;
        }*/
        ///this.nextSubmitScreen=false;
        //this.currentField=event.target.fieldName;  // the user has tabbed into a new field
        this.setIsEditingTrue();  //fire an event so parent components know an edit was made
        console.log('input Change');
        if(event.target.fieldName === 'Self_Employed_at_this_Job__c'){
            this.SelfEmployment = event.target.value?true:false;
        } 
        } catch (error) {
            this.error = error;
            this.showToast('Error', error.message, 'error');
            this.disableButton=false;
            createFutureErrorRecord( {exceptionMessage: error.message ?? error.body.message, stackTrace: error.stack ?? error.body.stackTrace, lineNum: 0, errortype: 'Javascript', procname: 'incomeSubTab.handleOnChange'}) ;                     
        }             
    }
    
    handleSuccess(event) { //event from a successful form submission--but this sometimes does not fire upon an update operation
        try {
            this.setIsEditingFalse();  // fire an event so parent components know an submit was made and that menu navigation is allowed
            //let tempdata;
            //this.recordId = this.selectedRecordId =  event.detail.id;  
            /*
            if(this.childSubPages === 'Previous Employment'){ //previousData is filtered from recordsData
                this.previousData = this.previousData.filter(item => item.Id !== event.detail.id); // remove it
                tempdata = [...this.previousData, {"Id":event.detail.id, "Name": event.detail.fields.Name.value, // add it back
                                    "Job_Title__c": event.detail.fields.Job_Title__c.value, 
                                    "Date_of_Hire__c": event.detail.fields.Date_of_Hire__c.value, "Date_Employment_Ended__c": event.detail.fields.Date_Employment_Ended__c.value,
                                    "Employer__c": event.detail.fields.Employer__c.value }];  
                this.previousData = tempdata; //reassign
            }else if(this.childSubPages === 'Current Employment'){ //currentData is filtered from recordsData
                if (event.detail.id){             
                    this.currentData = this.currentData.filter(item => item.Id !== event.detail.id);  // remove it
                    tempdata = [...this.currentData, // add it back
                        {"Id":event.detail.id, 
                        "Name": event.detail.fields.Name.value, 
                        "Job_Title__c": event.detail.fields.Job_Title__c.value, 
                        "Date_of_Hire__c": event.detail.fields.Date_of_Hire__c.value }];       
                    this.currentData=tempdata;  //reassign                                   
                }
            } else if (this.childSubPages === 'Tax Returns') {
                this.recordsData = this.recordsData.filter(item => item.Id !== event.detail.id);  // remove it
                tempdata = [...this.recordsData, // add it back
                    {"Id":event.detail.id, "Year__c":event.detail.fields.Year__c.value, 
                     "IRS_Form__c": event.detail.fields.IRS_Form__c.value, 
                     "Filing_Status__c": event.detail.fields.Filing_Status__c.value, 
                     "Taxable_Income__c": event.detail.fields.Taxable_Income__c.value }];
                this.recordsData=tempdata;  //reassign
            }  else { //all the other forms are just one record
                this.recordId = this.otherIncomeRecordId =  event.detail.id;                
            } */
        } catch (error) {
                createFutureErrorRecord( {exceptionMessage: error.message ?? error.body.message, stackTrace: error.stack ?? error.body.stackTrace, lineNum: 0, errortype: 'Javascript', procname: 'incomeSubTab.handleSuccess'}) ;  
        }
    }    

    handleSubmitForm(event) {      
    try {
        if (this.isEditing) { //only if a change has been made to one of the form fields
            this.template.querySelector('lightning-record-edit-form').submit(event.detail.fields);  // will call the onSuccess event handled by handleSuccess
            this.setIsEditingFalse();
            setTimeout(() => {             
                if(this.childSubPages === 'Previous Employment' || this.childSubPages === 'Current Employment') { 
                    this.handleGetEmploymentData();
                } else if (this.childSubPages === 'Tax Returns') {
                    this.handleGetTaxData();
                }             
            }, 1000 );
        }
        } catch (error) {
            this.error = error;
            this.showToast('Error', error.message, 'error');
            this.disableButton=false;
            createFutureErrorRecord( {exceptionMessage: error.message ?? error.body.message, stackTrace: error.stack ?? error.body.stackTrace, lineNum: 0, errortype: 'Javascript', procname: 'incomeSubTab.handleSubmitForm'}) ;                     
        }             
    }   

    incomeErrorMsgGenerator(fields){
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
    /*handleRefreshApex(){    
        refreshApex(this.wiredResults)
            .then( () => 
            {
                let result=this.wiredResults;  // run refreshApex against this, does not work for inserts & deletes
                if (result.data) {
                    this.recordsData = [...this.processData(result.data)]; 
                    if (map.has(this.objectName)) {
                        this.recordsData = map.get(this.objectName);
                    } else {
                        this.recordsData = this.processData(result.data);
                        map.set(this.objectName,this.recordsData);
                    }
                    this.currentData = this.recordsData.filter(item => item.Date_Employment_Ended__c === null );
                    this.previousData = this.recordsData.filter(item => item.Date_Employment_Ended__c !== null );
                }
            })
            .catch(error => {
                // Optional: Handle error during refresh
            });
    }*/

    async handleDeleteChild(event) {
        try {
        const childRecordId = event.currentTarget.dataset.id;
        const childRecordObject = event.currentTarget.dataset.field;
        handleDelete({ recordId: childRecordId, objectName: childRecordObject })
        .then( () => {
            this.showToast('Success', 'Record deleted successfully', 'success')
        })
        .catch(error => {
            this.showToast('Error', error.body, 'error');
        });
       
        if(this.childSubPages === 'Previous Employment'){
            this.previousData = this.previousData.filter(item => item.Id !== childRecordId);
        }
        if(this.childSubPages === 'Current Employment'){
            this.currentData = this.currentData.filter(item => item.Id !== childRecordId);
        }
        if (this.childSubPages === 'Tax Returns') {
            this.recordsData = this.recordsData.filter(item => item.Id !== childRecordId);
        }       

        //this.handleRefreshApex();
        //setTimeout(() => { this.handleRefreshApex();  }, 1000);

        } catch (e){
                createFutureErrorRecord( {exceptionMessage: e.message ?? e.body.message, stackTrace: e.stack ?? e.body.stackTrace, lineNum: 0, errortype: 'Javascript', procname: 'incomeSubTab.handleDeleteChild'}) ;                     
    }
    }
    get acceptedFormats() {
        return ['.pdf', '.png', '.jpg', '.jpeg', '.csv', '.docx', '.xlsx', '.xlsm', '.xls'];  //JPG, PDF, CSV, DOCX, XLSX
    }
    handleFileDelete(event) {
        try {
            const index = event.detail.name;
            let fileId;
            if (this.childSubPages === 'Tax Returns') {
                fileId = this.uploadedTaxReturnFile[index]?.id;
            } else {
                fileId = this.uploadedCurrentEmploymentFile[index]?.id;
            }
            if(fileId){
                deleteFileAndDocument({ contentVersionId: fileId })
                    .then(result => {
                        this.getFiles();
                        //this.showToast('Success', 'File deleted successfully!', 'success'); not needed
                    })
                    .catch(() => {
                        this.showToast('Error', 'Failed to delete file.', 'error');
                            createFutureErrorRecord( {exceptionMessage: error.message ?? error.body.message, stackTrace: error.stack ?? error.body.stackTrace, lineNum: 0, errortype: 'Javascript', procname: 'incomeSubPage.handleFileDelete'}) ;     
                    });            
            } else {
                    this.showToast('Error', 'Invalid file id!', 'error');
            }       
        } catch (e){
            createFutureErrorRecord( {exceptionMessage: e.message ?? e.body.message, stackTrace: e.stack ?? e.body.stackTrace, lineNum: 0, errortype: 'Javascript', procname: 'incomeSubPage.handleFileDelete'}) ;                     
        }
    }

    async getFiles()    {
        try {
            if (this.childSubPages === 'Tax Returns' || this.childSubPages === 'Current Employment') {        
                let files =  await getAssociatedFiles ( { recordId: this.selectedRecordId });
                this.error = undefined;
                if (this.childSubPages === 'Tax Returns') {
                    this.uploadedTaxReturnFile = files ? files.map((aFile) => {
                        return {    name: aFile.Title,  id: aFile.Id    };
                    })  : [];
                } else if (this.childSubPages === 'Current Employment')    {
                    this.uploadedCurrentEmploymentFile = files ? files.map((aFile) => { 
                        return {    name: aFile.Title,  id: aFile.Id    };
                    })  : [];                    
                }            
            }
        } catch (e){
            this.error = e;
            this.uploadedTaxReturnFile = [];
            this.uploadedCurrentEmploymentFile = [];
            createFutureErrorRecord( {exceptionMessage: e.message ?? e.body.message, stackTrace: e.stack ?? e.body.stackTrace, lineNum: 0, errortype: 'Javascript', procname: 'incomeSubTab.getFiles'}) ;                    
        }
    }

    handleUploadFinished(event){
        this.getFiles();
    }
    
    closeModal () {
        this.isModalOpen = false;
        const event = new CustomEvent('submitchild', {
            detail: true
        });
        this.dispatchEvent(event);
    }
    handleSubmitIncome () {
        if (this.ciFormStatus === 'Open') {
            this.isModalOpen = true;
        } else {
            this.closeModal();
        }
    }
}