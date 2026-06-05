import { LightningElement, api, wire, track } from 'lwc';
import updateRecordDetail from '@salesforce/apex/VitalAccountController.updateRecordDetail';
import { ShowToastEvent } from 'lightning/platformShowToastEvent';
import expenseLogo from '@salesforce/resourceUrl/expenseLogo';
import deleteFileAndDocument from '@salesforce/apex/FileUploadController.deleteFileAndDocument';
import getAssociatedFiles from '@salesforce/apex/FileUploadController.getAssociatedFiles';
import housingExpenses from './housingExpenses.html';
import utilities from './utilities.html';
import foodAndSupplies from './foodAndSupplies.html';
import healthCareCosts from './healthCareCosts.html';
import vehiclesTransportation from './vehiclesTransportation.html';
import monthlyPayrollExpenses from './monthlyPayrollExpenses.html';
import childrenExpensesActivities from './childrenExpensesActivities.html';
import yourEducationExpenses from './yourEducationExpenses.html';
import maintenanceChildSupport from './maintenanceChildSupport.html';
import entertainment from './entertainment.html';
import legalExpenses from './legalExpenses.html';
import miscellaneous from './miscellaneous.html';
export default class ExpensesSubTab extends LightningElement {
    @api childSubPages;
    @api pages;
    @api parentRecId;
    @api objectName;
    @api ciFormStatus;
    @api childMatterActivity;
    @api queryFields;
    @track error;
    @api objectApiName;
    @track selectedRecordId;
    selectedOption = 'Own';
    ownHome = true;
    addCreditCard = false;
    addDebts = false;
    addEmployment = false;
    employeePage = 0;
    addCurrentEmployment = false;
    addCurrentEmploymentIncome = false;
    addCurrentEmployer = false;
    addPreviousEmployer = false;
    addTax = false;
    expenseLogoImg = expenseLogo;
    isModalOpen = false;
    uploadedFileName = '';
    @track fileName=''
    @track listOfUploadedFileNames = [];
    /* 10/31 */
    isEditing=false;
    currentChildSubPages=undefined;  //used to track a change in the current form/page

    connectedCallback() {
        this.selectedRecordId = this.childMatterActivity;
       // this.recordDetail.Id = this.selectedRecordId;
       /* if (this.objectApiName === 'Matters__c' && this.parentRecId) {
            this.parentChildrenId = this.parentRecId; 
            this.parentChildrenField = 'Client_Name__c';
            this.recordDetail.Client_Name__c = this.parentRecId;
        }*/
    }
    render (event) {
        switch (this.childSubPages) {
            case 'Housing Expenses':
                this.saveChanges(event);
                return housingExpenses;
            case 'Utilities':
                this.saveChanges(event);                
                return utilities;
            case 'Food and Supplies':
                this.saveChanges(event);                
                return foodAndSupplies;
            case 'Health Care Costs':
                this.saveChanges(event);                
                return healthCareCosts;
            case 'Vehicles/Transportation':
                this.saveChanges(event);                
                return vehiclesTransportation;
            case 'Monthly Payroll Expenses':
                this.saveChanges(event);                
                return monthlyPayrollExpenses;
            case 'Children Expenses/Activities':
                this.saveChanges(event);                
                return childrenExpensesActivities;
            case 'Your Education Expenses':
                this.saveChanges(event);                
                return yourEducationExpenses;
            case 'Maintenance/Child Support':
                this.saveChanges(event);                
                return maintenanceChildSupport;
            case 'Entertainment':
                this.saveChanges(event);                
                return entertainment;
            case 'Legal Expenses':
                this.saveChanges(event);                
                return legalExpenses;
            case 'Miscellaneous':
                this.saveChanges(event);                
                return miscellaneous;
            default:
                return housingExpenses;
        }
    }
    /* changes 10/31 */

    saveChanges(event){
        try {
        if (this.currentChildSubPages!=this.childSubPages)  {
            this.handleSave(event);
            this.currentChildSubPages=this.childSubPages;
        }
        } catch (error) {
            createFutureErrorRecord( {exceptionMessage: error.message ?? error.body.message, stackTrace: error.stack ?? error.body.stackTrace, lineNum: 0, errortype: 'Javascript', procname: 'expensesSubTab.saveChanges'}) ;  
        }        
    }

    handleOnChange(event) { //whenever there is a change to a form field
    try {
        this.setIsEditingTrue();  //fire an event so parent components know an edit was made
        console.log('input Change');
        } catch (error) {
            this.error = error;
            this.showToast('Error', error.message, 'error');
            createFutureErrorRecord( {exceptionMessage: error.message ?? error.body.message, stackTrace: error.stack ?? error.body.stackTrace, lineNum: 0, errortype: 'Javascript', procname: 'expensesSubTab.handleOnChange'}) ;                     
        }             
    }    
    async handleSubmitExpensesSection(event) {  //....called from a event triggered on a button on the serviceOfPurposeOP page--only time this will be called....replaces saveRecord()
        try {
            this.handleSave(event);
            this.showToast('Success', 'Record updated successfully', 'success');
            setTimeout(() => {               
                if (this.ciFormStatus === 'Open') {
                    this.isModalOpen = true;
                } else {
                    this.closeModal();
                }
                if(this.childSubPages === 'Miscellaneous'){
                    this.handleSaveChild();
                }                    
            }, 2000);
        } catch (error) {
            createFutureErrorRecord( {exceptionMessage: e.message ?? e.body.message, stackTrace: e.stack ?? e.body.stackTrace, lineNum: 0, errortype: 'Javascript', procname: 'expensesSbuTab.handleSubmitExpensesSection'}) ;     
            this.error = error;
            this.showToast('Error',error.body ? error.body.message : 'Error Occured.', 'error');
        }
            setTimeout(() => {  this.isLoading = false; }, 1000);                   
    }  
    setIsEditingTrue () { //event propagates back to virtualAccountCreater as bubbles and composed are set to true
        this.isEditing=true;
        this.dispatchEvent(new CustomEvent("isediting", { detail: true, bubbles: true, composed:true }));     
    }  
    setIsEditingFalse () { //event propagates back to virtualAccountCreater
        this.isEditing=false;
        this.dispatchEvent(new CustomEvent("isediting", { detail: false, bubbles: true, composed: true }));              
    }
    handleSubmitForm(event) { // 10/30 
    try {
        if (!this.isEditing) { return; } //no edits to save; 
        this.template.querySelector('lightning-record-edit-form').submit();
        this.setIsEditingFalse;  
        } catch (error) {
            this.error = error;
            this.showToast('Error', error.message, 'error');
            this.disableButton=false;
            createFutureErrorRecord( {exceptionMessage: error.message ?? error.body.message, stackTrace: error.stack ?? error.body.stackTrace, lineNum: 0, errortype: 'Javascript', procname: 'vitalSubPage.handleSubmitForm'}) ;                     
        }             
    }     
    async handleSave(event) {
        try{
            this.isLoading = true;
            this.handleSubmitForm(event);  //performs the upsert by submitting the form --           
            this.setIsEditingFalse();  // reset it here instead of in handleSuccess because the form may go out of scope before handleSuccess is called.  VirtualAccountCreater then thinks that there are uncommitted changes. 
            this.isLoading = false;    
        } catch (error) {
            createFutureErrorRecord( {exceptionMessage: e.message ?? e.body.message, stackTrace: e.stack ?? e.body.stackTrace, lineNum: 0, errortype: 'Javascript', procname: 'childrenSubPage.handleSave'}) ;          
            this.showToast('Error', error.message, 'error');
        }
        setTimeout(() => {
            this.isLoading = false;
            }, 3000);        
    }    
    handleUploadFinished(event) { // to refresh the file list
        this.getFiles();
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
    /* 10/31 changes */        
    async getFiles()    {
        try {            
            let files =  await getAssociatedFiles ( { recordId: this.selectedRecordId });
            this.error = undefined;
            this.listOfUploadedFileNames = files ? files.map((aFile) => {
                return {    name: aFile.Title,  id: aFile.Id    };
            })  : [];                       
        } catch (e){
            this.error = e;
            this.listOfUploadedFileNames = [];        
            createFutureErrorRecord( {exceptionMessage: e.message ?? e.body.message, stackTrace: e.stack ?? e.body.stackTrace, lineNum: 0, errortype: 'Javascript', procname: 'debtsSubTab.getFiles'}) ;                    
        }
    }  
    /* 10/24 changes */        


    handleSaveChild () {
        const event = new CustomEvent('savechild', {
            detail: true
        });
        this.dispatchEvent(event);
    }
    /*async handleSave() {
        this.isLoading = true;
        try {
            if(this.recordId) {
                updateRecordDetail({recordDetail: JSON.stringify(this.recordDetail), objectApiName: this.objectApiName})
                    .then(result => {
                        this.recordId=result;
                        getRecordNotifyChange([{ recordId: this.recordId }]);
                        this.showToast('Success', 'Record updated successfully', 'success');
                    })
                    .catch(error => {
                        this.showToast('Error',error.body ? error.body.message : 'Error Occured While Saving Data.' , 'error');
                    });
                    this.listOfUploadedFileNames=[];                
            } else {
                updateRecordDetail({recordDetail: JSON.stringify(this.recordDetail), objectApiName: this.objectApiName})
                .then(result => {
                    this.showToast('Success', 'Record created successfully', 'success');
                    this.recordId = undefined;
                    this.recordId =  result;
                    getRecordNotifyChange([{ recordId: this.recordId }]);
                    this.isEditing = false;
                    if (this.ciFormStatus === 'Open') {
                        this.isModalOpen = true;
                    } else {
                        this.closeModal();
                    }
                    if(this.childSubPages === 'Miscellaneous'){
                        this.handleSaveChild();
                    }
                    
                })
                .catch(error => {
                    this.showToast('Error',error.body ? error.body.message : 'Error Occured While Saving Data..' , 'error');
                });
                this.listOfUploadedFileNames=[];
            }
        } catch (error) {
            this.error = error;
            this.showToast('Error',error.body ? error.body.message : 'Error Occured.', 'error');
        }

        setTimeout(() => {
            this.isLoading = false;
        }, 3000);  
    }*/
    showToast(title, message, variant) {
        const event = new ShowToastEvent({
            title: title,
            message: message,
            variant: variant,
        });
        this.dispatchEvent(event);
    }
    get getButtonClassOpposing() {
        return `toggle-button ${this.selectedOption === 'Own' ? 'selected' : ''}`;
    }
    get getButtonClassOther() {
        return `toggle-button ${this.selectedOption === 'Rent' ? 'selected' : ''}`;
    }
    handleToggle(event) {
        this.selectedOption = event.target.dataset.option;
        this.isToggle = true;
        if (this.selectedOption === 'Own') {
            this.ownHome = true;
        } else {
            console.log('getting toggle else : ');
            this.ownHome = false;
        }
    }
    closeModal() {
        this.isModalOpen = false;
    }

}