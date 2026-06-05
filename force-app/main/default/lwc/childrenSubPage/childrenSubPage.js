import { LightningElement, api, wire, track } from 'lwc';
import getCurrentUserAccountId from '@salesforce/apex/ChildrenController.getCurrentUserAccountId';
import getAccountDetails from '@salesforce/apex/VitalAccountController.getAccountDetails';
import updateMatter from '@salesforce/apex/VitalAccountController.updateMatter';
import getActivitiesList from '@salesforce/apex/ChildrenController.getActivitiesList';
import ChildrenLogo from '@salesforce/resourceUrl/ChildrenLogo';
import getMedicalProvidersList from '@salesforce/apex/ChildrenController.getMedicalProvidersList';
import {getRecordNotifyChange } from 'lightning/uiRecordApi';
import { ShowToastEvent } from 'lightning/platformShowToastEvent';
import yourChildren from './yourChildren.html';
import childrenVitalInformation from './childrenVitalInformation.html';
import extraCurricularActivities from './extraCurricularActivities.html';
import medicalProviders from './medicalProviders.html';
import childrenVitalInformationOther from './childrenVitalInformationOther.html';
import handleDelete from '@salesforce/apex/ChildrenController.handleDelete';
import getChildrenList from '@salesforce/apex/ChildrenController.getChildrenList';
import { refreshApex } from '@salesforce/apex';
import createFutureErrorRecord from "@salesforce/apex/Utility.createFutureErrorRecord";

export default class ChildrenSubPage extends LightningElement {
    @api childSubPages;
    @api pages;
    @api addChildSub;
    @api childMatterId;
    @api childMatterActivity;
    @api childAccountId;
    @api ciFormStatus;
    @api selectedRecordId;
    @track parentAccountId = '';
    @track selectedActivityData = {};
    @track wiredChildrenList;     
    @track extraCurricularData = [];
    @track medicalProviderData = [];
    @track parent1Data = {};
    @track parent2Data = {};
    @track childErrorValue=[];
    @track transformedData = [];
    /* Don */   
    isToggle = false;
    addLabel = 'Add';
    addLabelOther = 'Add';
    addExtraCurricular = 'Add';
    addMedical = 'Add';
    vitalLogoImg = ChildrenLogo;
    isModalOpen = false;
    wiredMatter;
    recordId;
    showServiceSpinner;
    childActivity;
    medicalActivity;
    selectedOption = 'Opposing Party';
    opposingParty = true;
    childName;
    addChild = true;
    addChildSubTab1 = false;
    addChildSubTab2 = false;
    birthParenting = false;
    schoolEducation = false;
    childCare = false;
    childrenVitalPage = 1;
    addActivity = true;
    addMedicalProvider = true;
    selectedChildRecordId = '';
    nameError;
    stateError;
    addressError;
    socialSecurityError;
    dobError;
    childResidesWithError;
    birthPlaceError;
    childValidation=true;
    parent_1=undefined;
    parent_2=undefined;
    isEditing=false;
    //added 11/3
    isloading=true; 
    errors=undefined;
    account=undefined;
    matter=undefined;
    dayMapping = {
        Monday: 'M',
        Tuesday: 'Tu',
        Wednesday: 'W',
        Thursday: 'Th',
        Friday: 'F',
        Saturday: 'Sa',
        Sunday: 'Su',
    };
  
    @wire (getChildrenList)
    wiredChildren(result) {
        this.wiredChildrenList = result;
        const { error, data } = result;
        if(data) {
            this.parent1Data ={};
            this.parent2Data ={};          
            this.parent1Data = data?.filter(child => child?.Parent_1__c != null);
            this.parent2Data = data?.filter(child => child?.Parent_2__c != null);           
            this.isLoading = false;
            this.errors = null;
            console.log('parent1Data:  '+JSON.stringify(this.parent1Data));
            console.log('parent2Data:  '+JSON.stringify(this.parent2Data));
        } else if (error) {
            this.errors = error;
            this.parent1Data = null;
            this.parent2Data = null;
        }
    }
    @wire(getCurrentUserAccountId)
    wiredAccountId({ error, data }) {
        if (data) {
            this.parentAccountId = data;
        } else if (error) {
            console.error('Error retrieving account ID:', error);
        }
    }
    @wire(getAccountDetails, {  })
    wiredAccount(result) {
        this.wiredMatter = result;
        let data = result.data;
        let error = result.error;
        if (data) {
            this.account = data.acc;
            this.matter = data.matter;
            this.errors = null;
        } else if (error) {
            this.errors = error;
            this.account = null;
        }
    }
    render () {
        switch (this.childSubPages) {
            case 'Children Vital Information':
                return childrenVitalInformation;
            case 'Your Children':
                return yourChildren;
            case 'Extracurricular Activities':
                return extraCurricularActivities;
            case 'Medical Providers':
                return medicalProviders;
            case 'Children Vital Information-Others':
                return childrenVitalInformationOther; 
            default:
                return yourChildren;
        }
    }
    showToast(title, message, variant) {
        this.dispatchEvent(new ShowToastEvent({ title, message, variant }));
    } 
    handleNext (event) {
        //console.log('JSON.parse(JSON.stringify(event ))', JSON.parse(JSON.stringify(event )));   
        this.handleSubmitForm(event);
        if (this.childrenVitalPage < 7) {
            this.childrenVitalPage++;
        }
        if (this.childSubPages === 'Children Vital Information') {
            this.addChild = this.childrenVitalPage === 1;
            this.addChildSubTab1 = this.childrenVitalPage === 2;
            this.addChildSubTab2 = this.childrenVitalPage === 3;
            this.birthParenting = this.childrenVitalPage === 4;
            this.schoolEducation = this.childrenVitalPage === 5;
            this.childCare = this.childrenVitalPage === 6;
        }
        if (this.childrenVitalPage === 7 || this.childSubPages === 'Children Vital Information-Others') {
            this.handleSaveChild();
            this.childrenVitalPage = 1;
        }
        this.videoChange();    
    }
    videoChange(){ //We have to change the videos for each children sub form
            let event;
            if (this.addchild===true || this.addChildSubTab1===true || this.addChildSubTab2===true ){    event = new CustomEvent("videochange", { detail: 'Children Address Guardian' });    }  
            if (this.birthParenting===true){    event = new CustomEvent("videochange", { detail: 'Children Birth Parenting' });     }
            if (this.schoolEducation===true){   event = new CustomEvent("videochange", { detail: 'Children School Education' });    }
            if (this.childCare===true){     event = new CustomEvent("videochange", { detail: 'Children Childcare' });   }
            if (event) { this.dispatchEvent(event);   }
    }
    childErrorMsgGenerator(fields){
        let fieldData = fields;
        let errorMsg = ''
        fieldData.forEach(field =>{
            if((!field.value || field.value.trim?.() === '') && field.mandatory == true){
                let fldName = field.fieldName == 'Name'?'Name':field.fieldName.replaceAll("_"," ").slice(0,-3);
                errorMsg += 'Please check '+fldName+' field it is required.\n';                  
            }
        });
        if(errorMsg){
            this.showToast('Error In Child Section Section', errorMsg, 'error');
        }
    }
    handlePrevious (event) {
        this.handleSubmitForm(event);
        this.childrenVitalPage = this.childrenVitalPage - 1;
        if (this.childSubPages === 'Children Vital Information') {
            this.addChild = this.childrenVitalPage === 1;
            this.addChildSubTab1 = this.childrenVitalPage === 2;
            this.addChildSubTab2 = this.childrenVitalPage === 3;
            this.birthParenting = this.childrenVitalPage === 4;
            this.schoolEducation = this.childrenVitalPage === 5;
            this.childCare = this.childrenVitalPage === 6;
            this.videoChange();
        }
    }
    get managePreviousButtons () {
        if (this.childrenVitalPage > 1) {
            return true;
        }
        return false;
    }
    get manageNextButtons () {
        if (this.childrenVitalPage === 1) {
            return false;
        }
        return true;
    }   
    get manageNextButtons1 () {
        if (this.childrenVitalPage === 6) {
            return false;
        }
        return true;  
    }
    get manageSaveButtons () {
        if (this.childrenVitalPage === 6) {
            return true;
        }
        return false;
    }
    handleAddActivity () {
        this.addActivity = false;
        this.addExtraCurricular = 'Add';
    }
    handleCancelActivity () {
        this.addActivity = true;
        this.childActivity = '';
    }
    handleMedicalProvider () {
        this.addMedicalProvider = false;
        this.addMedical = 'Add';
        this.medicalActivity = '';
    }
    handleCancelMedical () {
        this.addMedicalProvider = true;
        this.medicalActivity = '';
    }    
    handleAddChild () { 
        this.addLabel = 'Update';
        this.addLabelOther = 'Update';
        const party = this.selectedOption === 'Opposing Party' ? 'Children With OP' : 'Children from a Different Relationship';
        const tab = this.selectedOption === 'Opposing Party' ? 'Children Vital Information' : 'Children Vital Information-Others';
        const event = new CustomEvent('addchild', {
            detail: {
                field: true,
                value: party,
                tabName: tab
            }
        });
        this.dispatchEvent(event);
    }

    handleAddChildBtn () {
        this.selectedChildRecordId = '';
        this.childrenVitalPage = 1;
        this.addChild = true;
        this.addChildSubTab1 = false;
        this.addChildSubTab2 = false;
        this.birthParenting = false;
        this.schoolEducation = false;
        this.childCare = false;
        this.videoChange();
        if (this.selectedOption === 'Opposing Party') {
            this.parent_1 = this.parentAccountId; 
            this.parent_2 = undefined;            
        } else {
            this.parent_1 = undefined;
            this.parent_2 = this.parentAccountId;    
        }
        this.isToggle = false;        
        this.handleToggleForChild();
    }
    handleSaveChild () {
        const event = new CustomEvent('savechild', {
            detail: true
        });
        this.dispatchEvent(event);
    }
    handleCancelChild () { 
        this.selectedChildRecordId = '';
        const event = new CustomEvent('cancelchild', {
            detail: true
        });
        this.dispatchEvent(event);
    }
    handleCellClick(event) {
        this.recordId = event.currentTarget.dataset.id;
        this.handleAddChild();
        this.selectedChildRecordId = this.recordId;
        this.childName = event.currentTarget.dataset.field;
        if (this.recordId) {
            getActivitiesList({childId: this.recordId}).then((result) => {
                this.extraCurricularUIData = result;
                this.transformedData = result.map(record => ({
                    ...record,
                    whoPaysName: record.Who_Pays_for_Activity_Text__c || '',
                    test: record?.Weekly_Schedule__c?.split(';')?.map(day => this.dayMapping[day] || day).join(';')}))
                this.extraCurricularData = this.transformedData ? [...this.transformedData] : [...result];                
            })
            getMedicalProvidersList({childId: this.recordId}).then((result) => {
                this.medicalProviderData = [...result];
            })

        }
        if (!this.childSubPages) {
            this.handleSaveChild();
        }
    }
/*
    handleCellClick(event) {
        this.recordId = event.currentTarget.dataset.id;
        this.handleAddChildBtn();
        this.selectedChildRecordId = this.recordId;
        this.childName = event.currentTarget.dataset.field;
        if (this.recordId) {
            getActivitiesList({childId: this.recordId}).then((result) => {
                this.transformedData = result.map(record => ({
                    ...record,
                    whoPaysName: record.Who_Pays_for_Activity_Text__c || '',
                    test: record?.Weekly_Schedule__c?.split(';')?.map(day => this.dayMapping[day] || day).join(';')}))
                this.extraCurricularData = this.transformedData ? [...this.transformedData] : [...result];                
            })
            getMedicalProvidersList({childId: this.recordId}).then((result) => {
                this.medicalProviderData = [...result];
            })

        }
        if (!this.childSubPages) {
            this.handleSaveChild();
        }
    }
*/
    handleActivityClick (event) {
        this.childActivity = ''
        this.addActivity = false
        this.addExtraCurricular = 'Update';
        const recordId = event.currentTarget.dataset.id;
        this.childActivity = recordId;
        console.log('this.childActivity>',this.childActivity ,'recordId; =>', recordId);
    }
    handleMedicalClick (event) {
        this.medicalActivity = '';
        this.addMedicalProvider = false;
        this.addMedical = 'Update';
        const recordId = event.currentTarget.dataset.id;
        this.medicalActivity = recordId;
        console.log('handleMedicalClick this.medicalActivity>',this.medicalActivity ,'recordId; =>', recordId);
        this.updatedMedicalData = this.medicalProviderData.filter(extra => extra.Id == this.medicalActivity);
    }
    handleSaveActivity (event) {
        try {
            let fieldData = [];
            let isValid = true;
            const inputFields = this.template.querySelectorAll('lightning-input-field');        
            inputFields.forEach(field => {
                fieldData.push({
                    fieldName: field.fieldName,
                    value: field.value,
                });  
            });
            fieldData.forEach(field => {
                console.log(field.fieldName,'-----',field.value);          
                if (field.fieldName === 'Who_Pays_for_Activity_Text__c' && (!field.value)) {                
                    isValid = false;
                }
            });
            console.log(isValid,'----isisValid');
            if(!isValid) {
                this.showToast('Error', 'Please provide all the required fields...', 'error');
                return;
            } 

            if(isValid){
                this.handleSubmitForm(event);     
                setTimeout(() => {
                    getActivitiesList({childId: this.selectedChildRecordId}).then((result) => {
                        this.transformedData = result.map(record => ({
                            ...record,
                            whoPaysName: record.Who_Pays_for_Activity_Text__c || '',
                            test: record?.Weekly_Schedule__c?.split(';')?.map(day => this.dayMapping[day] || day).join(';')}));
                        this.extraCurricularData = this.transformedData ? [...this.transformedData] : [...result];
                        this.handleCancelActivity();
                    })
                    this.dispatchEvent(
                        new ShowToastEvent({
                            title: 'Success',
                            message: 'ExtraCurricular Activity is Added successfully',
                            variant: 'success',
                            mode: 'dismissable'
                        })
                    );
                }, 2000);
    
            } 
        } catch (e){
            createFutureErrorRecord( {exceptionMessage: e.message ?? e.body.message, stackTrace: e.stack ?? e.body.stackTrace, lineNum: 0, errortype: 'Javascript', procname: 'chidrenSubPage.handleSaveActivity'}) ;                     
        } 
    }
    
    handleSaveMedical (event) {
        try {
            /*let index = this.medicalProviderData.findIndex(item => item.Id === this.medicalActivity);
            index = (index === -1) ? 0 : index;
            this.medicalProviderData[index].Matter__c = this.childMatterActivity;
            this.medicalProviderData[index].Child_Name__c = this.recordId;   */
            this.handleSubmitForm(event);        
            setTimeout(() => {    
                getMedicalProvidersList({childId: this.recordId}).then((result) => {
                    this.medicalProviderData = [...result];
                })
                .catch(error => {
                    this.errors = error;
                    console.error('Error updating Account or Matter:', error);
                });
                console.log('----this.updatedMedicalData2',JSON.stringify(this.medicalProviderData))
                this.dispatchEvent(
                    new ShowToastEvent({
                        title: 'Success',
                        message: 'Medical Activity is Added successfully',
                        variant: 'success',
                        mode: 'dismissable'
                    })
                );
            }, 2000);    
            this.addMedicalProvider = true;
            this.selectedRecordId = '';
            this.medicalActivity='';
            this.handleCancelMedical();
        } catch (e){
            createFutureErrorRecord( {exceptionMessage: e.message ?? e.body.message, stackTrace: e.stack ?? e.body.stackTrace, lineNum: 0, errortype: 'Javascript', procname: 'chidrenSubPage.handleSaveMedical'}) ;                     
        }           
    }

    /* 10/24 changes */
    get isInsert(){ //if it's an insert we need to set a default value for certain fields 
        if (this.selectedChildRecordId && this.selectedChildRecordId!=='' && this.selectedChildRecordId!==undefined){
            return false;
        }
        return true;
    }
    handleOnChange(event) { //whenever there is a change to a form field
    try {
        if (this.addNewOrEditExistingRecord){ // triggered from employment edit or add buttons which calls handleEmployeeNext even though no edits have been made
            this.addNewOrEditExistingRecord=false;              
            return;
        }
        this.setIsEditingTrue();  //fire an event so parent components know an edit was made
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
            this.showServiceSpinner = false; 
            switch (this.childSubPages) {
                case 'Children Vital Information':
                    this.selectedChildRecordId =  event.detail.id;
                    getRecordNotifyChange([{ recordId: this.selectedChildRecordId }]);  
                    refreshApex(this.wiredChildrenList);
                case 'Children Vital Information-Others':
                    this.selectedChildRecordId =  event.detail.id;
                    getRecordNotifyChange([{ recordId: this.selectedChildRecordId }]);  
                    refreshApex(this.wiredChildrenList);               
            }         
        } catch (error) {
                createFutureErrorRecord( {exceptionMessage: error.message ?? error.body.message, stackTrace: error.stack ?? error.body.stackTrace, lineNum: 0, errortype: 'Javascript', procname: 'debtsSubTab.handleSuccess'}) ;  
        }
    }  
    handleSubmitForm(event) { // 10/30 special case to get this to work--event comes in empty for some reason so we query the form
    try {
        /* if (this.isEditing) { //only if a change has been made to one of the form fields
            this.template.querySelector('lightning-record-edit-form').submit(event.detail.fields);  // will call the onSuccess event handled by handleSuccess
            this.setIsEditingFalse();     
        } 
            const inputFields = this.template.querySelectorAll('lightning-input-field');        
            inputFields.forEach(field => {
                if (field.fieldName==='Time_in_Jurisdiction__c' && (field.value==null || field.value==undefined)){
                    field.value='0';
                }
            });
            this.template.querySelector('lightning-record-edit-form').submit(inputFields);  //special form submission as we have updated a field in JS             
        */
        if (!this.isEditing) { return; } //no edits to save
        this.showServiceSpinner = true; 
        const inputFields = this.template.querySelectorAll('lightning-input-field');  //have to query the input fields separately. Child_Resides_With__c
        const fieldsToSubmit = {};
        inputFields.forEach(field => {
            if (field.fieldName==='Time_in_Jurisdiction__c' && (field.value==null || field.value==undefined)){
                    field.value='0';            
                    fieldsToSubmit[field.fieldName] = field.value;
            } 
            else if (field.fieldName==='Child_Resides_With__c' && (field.value==null || field.value==undefined)){
                    field.value='Both';            
                    fieldsToSubmit[field.fieldName] = field.value;
            }
            else if (field.fieldName && field.value !== undefined) {
                fieldsToSubmit[field.fieldName] = field.value;
            }
        });
        this.template.querySelector('lightning-record-edit-form').submit(fieldsToSubmit);
        this.setIsEditingFalse;  //to handle the case when the submission is not successful
        this.showServiceSpinner = false;  // to handle the case when a different page is rendered and handleSuccess is not run
        } catch (error) {
            this.showServiceSpinner = false; 
            this.error = error;
            this.showToast('Error', error.message, 'error');
            this.disableButton=false;
            createFutureErrorRecord( {exceptionMessage: error.message ?? error.body.message, stackTrace: error.stack ?? error.body.stackTrace, lineNum: 0, errortype: 'Javascript', procname: 'vitalSubPage.handleSubmitForm'}) ;                     
        }             
    }     
    async handleSave(event) {
        try{
            this.isLoading = true;
            if (event.detail) { //we only want to save data if there has been a data change
                this.handleSubmitForm(event);  //performs the upsert by submitting the form -- 
            }
            this.addCreditCard = false;
            this.addDebitCard = false;            
            this.setIsEditingFalse();  // reset it here instead of in handleSuccess because the form may go out of scope before handleSuccess is called.  VirtualAccountCreater then thinks that there are uncommitted changes.     
        } catch (error) {
            createFutureErrorRecord( {exceptionMessage: e.message ?? e.body.message, stackTrace: e.stack ?? e.body.stackTrace, lineNum: 0, errortype: 'Javascript', procname: 'childrenSubPage.handleSave'}) ;          
            this.showToast('Error', error.message, 'error');
        }
        setTimeout(() => {
            this.isLoading = false;
            }, 3000);        
    }    

    /* 10/24 changes */        

    closeModal () {
        this.isModalOpen = false;
        const event = new CustomEvent('submitchild', {
            detail: true
        });
        this.dispatchEvent(event);
    }
    saveChildRecord(event) {         
        try{
            this.showServiceSpinner = true;                       
            this.handleSubmitForm();
            setTimeout(() => {
                this.showToast('Success', 'Record is saved successfully', 'success');
                this.recordId = '';
                this.childrenVitalPage = 1;
                this.addChild = true;
                this.addChildSubTab1 = false;
                this.addChildSubTab2 = false;
                this.birthParenting = false;
                this.schoolEducation = false;
                this.childCare = false;
                this.videoChange();
                this.childSubPages = 'Your Children';
                this.isToggle = true;
                this.handleResetProgressChild();
                this.showServiceSpinner = false;   
                this.setIsEditingFalse;              
            }, 3000);
        } catch (error) {
            createFutureErrorRecord( {exceptionMessage: e.message ?? e.body.message, stackTrace: e.stack ?? e.body.stackTrace, lineNum: 0, errortype: 'Javascript', procname: 'childrenSubPage.saveChildRecord'}) ;          
            this.showToast('Error', error.message, 'error');
        }
    }
    handleDoneWithProvider(){
        try {
            const party = this.selectedOption === 'Opposing Party' ? 'Children With OP' : 'Children from a Different Relationship';
            const tab = this.selectedOption === 'Opposing Party' ? 'Children Vital Information' : 'Children Vital Information-Others';
            const event = new CustomEvent('donewithprovider', {
                detail: {
                    field: true,
                    value: party,
                    tabName: tab,
                    toggle: this.isToggle
                }
            });
            this.dispatchEvent(event);   
            this.childSubPages = 'Your Children';
        } catch (error) {
            createFutureErrorRecord( {exceptionMessage: e.message ?? e.body.message, stackTrace: e.stack ?? e.body.stackTrace, lineNum: 0, errortype: 'Javascript', procname: 'childrenSubPage.handleDoneWithProvider'}) ;          
            this.showToast('Error', error.message, 'error');
        }
    }
    handleResetProgressChild () {
        //this.handleRefreshChildData();
        this.handleCancelChild();
        const party = this.selectedOption === 'Opposing Party' ? 'Children With OP' : 'Children from a Different Relationship';
        const tab = this.selectedOption === 'Opposing Party' ? 'Children Vital Information' : 'Children Vital Information-Others';
        const event = new CustomEvent('resetchild', {
            detail: {
                field: true,
                value: party,
                tabName: tab,
                toggle: this.isToggle
            }
        });
        this.dispatchEvent(event);
    }
    handleToggle(event) {
        this.selectedOption = event.target.dataset.option;
        this.isToggle = true;
        console.log('Line 948',this.isToggle);
        this.handleDoneWithProvider();
        if (this.selectedOption === 'Opposing Party') {
            this.opposingParty = true;
        } else {
            this.opposingParty = false;
        }



    }
    handleToggleForChild () {
        this.addLabel = 'Add';
        this.addLabelOther = 'Add';
        const isToggle = this.isToggle;
        const party = this.selectedOption === 'Opposing Party' ? 'Children With OP' : 'Children from a Different Relationship';
        const tab = this.selectedOption === 'Opposing Party' ? 'Children Vital Information' : 'Children Vital Information-Others';
        const event = new CustomEvent('addtogglechild', {
            detail: {
                field: true,
                value: party,
                tabName: tab,
                toggle: isToggle
            }
        });
        this.dispatchEvent(event);
    }
    get getButtonClassOpposing() {
        return `toggle-button ${this.selectedOption === 'Opposing Party' ? 'selected' : ''}`;
    }
    get getButtonClassOther() {
        return `toggle-button ${this.selectedOption === 'Other' ? 'selected' : ''}`;
    }
    handleDeleteChild(event) {
        try{
            const childRecordId = event.currentTarget.dataset.id;
            const childRecordObject = event.currentTarget.dataset.field;   
            handleDelete({ recordId: childRecordId, objectName: event.currentTarget.dataset.field })
                .then(() => {
                    if (childRecordObject === 'Activities__c') {
                        getActivitiesList({childId: this.recordId}).then((result) => { //TODO this.recordId in most cases is nto the same as the childRecordId value so what is the point here?
                            this.extraCurricularData = [...result];
                        })
                    } else if (childRecordObject === 'Medical_Providers__c') {
                        getMedicalProvidersList({childId: this.recordId}).then((result) => {
                            this.medicalProviderData = [...result];
                        })
                    } else {
                        refreshApex(this.wiredChildrenList);  //it must have been from a child deletion
                    }
                    this.showToast('Success', 'Record deleted successfully', 'success');
                })
                .catch(error => {
                    this.showToast('Error', error.body.message, 'error');
                    createFutureErrorRecord( {exceptionMessage: e.message ?? e.body.message, stackTrace: e.stack ?? e.body.stackTrace, lineNum: 0, errortype: 'Javascript', procname: 'childrenSubPage.handleDeleteChild'}) ;                     
                });
        } catch (error) {
            createFutureErrorRecord( {exceptionMessage: e.message ?? e.body.message, stackTrace: e.stack ?? e.body.stackTrace, lineNum: 0, errortype: 'Javascript', procname: 'childrenSubPage.handleDeleteChild'}) ;          
            this.showToast('Error', error.message, 'error');
        }            
    }

    saveMatter(event) {
        try { 
            this.showServiceSpinner = true; 
            this.handleSubmitForm(event);
            this.setIsEditingFalse;            
            setTimeout(() => {                  
                this.errors = undefined;
                this.showServiceSpinner = false;
                this.dispatchEvent(
                    new ShowToastEvent({
                        title: 'Success',
                        message: 'Matter updated successfully',
                        variant: 'success',
                        mode: 'dismissable'
                    })
                );
                if (this.ciFormStatus === 'Open') {
                    this.isModalOpen = true;
                } else {
                    this.closeModal();
                }
                refreshApex(this.wiredMatter)        
            }, 4000);            
        } catch (error) {
            createFutureErrorRecord( {exceptionMessage: e.message ?? e.body.message, stackTrace: e.stack ?? e.body.stackTrace, lineNum: 0, errortype: 'Javascript', procname: 'childrenSubPage.saveMatter'}) ;          
            this.showToast('Error', error.message, 'error');
        }          
    }
    /*
    validateMandatoryFields(){
        this.validateName(this.selectedChildData.Name);
        this.validateState(this.selectedChildData.State__c);
        this.validateCurrentAddress(this.selectedChildData.Street__c);
        this.validateSocialSecurityNumber(this.selectedChildData.Social_Security_Number__c);
        this.validateDOB(this.selectedChildData.Date_of_Birth__c);
        this.validateChildResidesWith(this.selectedChildData.Child_Resides_With__c);
        this.validateBirthPlace();
    }*/
    validateName(value) {
        this.nameError = !value;
        console.error('Name Error:', this.nameError);
        this.ChildInformationValidation();
    }   
    validateState(value) {
        this.stateError = !value;
        console.error('State Error:', this.stateError);
        this.ChildInformationValidation();
    }   
    validateCurrentAddress(value) {
        this.addressError = !value || value.length < 5;
        console.error('Address Error:', this.addressError);
        this.ChildInformationValidation();
    }   
    validateSocialSecurityNumber(value) {
        const socialPattern = /^\D*(\d\D*){9}$/;
        this.socialSecurityError = !value || !socialPattern.test(value);
        console.error('SSN Error:', this.socialSecurityError);
        this.ChildInformationValidation();
    }  
    validateDOB(value) {
        this.dobError = !value;
        console.error('DOB Error:', this.dobError);
        this.ChildInformationValidation();
    }   
    validateChildResidesWith(value) {
        this.childResidesWithError = !value;
        console.error('Child Resides With Error:', this.childResidesWithError);
        this.ChildInformationValidation();
    }   
    /*
    validateBirthPlace() {
        const city = this.selectedChildData.Birth_City__c;
        const state = this.selectedChildData.Birth_State__c;
        const country = this.selectedChildData.Birth_Country__c;
        this.birthPlaceError = !(city && state && country);
        console.error('Birth Place Error:', this.birthPlaceError);
        this.ChildInformationValidation();
    }*/
    ChildInformationValidation() {
        this.childValidation;
        if (this.nameError && this.stateError && this.addressError && this.socialSecurityError && this.dobError && this.childResidesWithError && this.birthPlaceError) {
            childValidation = false;
        } else {
            childValidation = true;
        }
        this.childErrorValue.push({
            nameError: this.nameError,
            stateError: this.stateError,
            addressError: this.addressError,
            socialSecurityError: this.socialSecurityError,
            dobError: this.dobError,
            childResidesWithError: this.childResidesWithError,
            birthPlaceError: this.birthPlaceError
        });   
    }  
}