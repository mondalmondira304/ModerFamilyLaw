import { LightningElement, api, track, wire } from 'lwc';
import getAccountDetails from '@salesforce/apex/VitalAccountController.getAccountDetails';
import vitalsPage from './vitalsPage.html';
import childrenPage from './childrenPage.html';
import opposingPartyPage from './opposingPartyPage.html';
import assetsPage from './assetsPage.html';
import debtsPage from './debtsPage.html';
import incomePage from './incomePage.html';
import expensesPage from './expensesPage.html';
import additionalUploadsPage from './additionalUploads.html';
import {CONSTANT} from "./Constant";
import createFutureErrorRecord from "@salesforce/apex/Utility.createFutureErrorRecord";

export default class VirtualAccountCreaterPages extends LightningElement {
    @api pages;
    @api subPages;
    @api parentAddChild;
    @api matterId;
    @api matterActivityIdParent;
    @api clientId;
    @api formStatus;
    @api clientName;
    @track accountWired;
    @track fieldsToQuery = [];
    objectName = 'Vehicles__r';
    childObjectAPIName = 'Vehicle__c'
    fileName = '';
    tabName = 'Vitals';
    selectedRecordId;
    @wire(getAccountDetails, {  })
    wiredAccount(result) {
        try{
            this.accountWired = result;
            const { error, data } = result;
            if (data) {
                this.selectedRecordId = data.acc.Id;
                this.errors = null;
            } else if (error) {
                this.errors = error;
                this.account = null;
            }
            }
        catch(error){
            createFutureErrorRecord( {exceptionMessage: error.message ?? error.body.message, stackTrace: error.stack ?? error.body.stackTrace, lineNum: 0, errortype: 'Javascript', procname: 'virtualAccountCreaterPages.wiredAccount'}) ;
        }        
    }
    render () {
        switch (this.pages) {
            case 'Vitals':
                return vitalsPage;
            case 'Children':
                return childrenPage;
            case 'Opposing Party':
                return opposingPartyPage;
            case 'Assets':
                return assetsPage;
            case 'Debts':
                return debtsPage;
            case 'Income':
                return incomePage;
            case 'Expenses':
                return expensesPage;
            case 'Additional Uploads':
                return additionalUploadsPage;
            default:
                return vitalsPage;
        }
    }   
    handleVideoChange(event) {
        const customEvent = new CustomEvent('videochange', {
            detail: event.detail
        });
        this.dispatchEvent(customEvent);
    }    
    handleSubAddChild(event) {
        const customEvent = new CustomEvent('subchild', {
            detail: event.detail
        });
        this.dispatchEvent(customEvent);
    }
    handleSubToggleChild(event) {
         const customEvent = new CustomEvent('togglesubchild', {
            detail: event.detail
        });
        this.dispatchEvent(customEvent);
    }
    handleResetChild(event) {
         const customEvent = new CustomEvent('resetsubchild', {
            detail: event.detail
        });
        this.dispatchEvent(customEvent);
    }
    handleDoneWithProvider(event){
        const customEvent = new CustomEvent('donewiththeprovider', {
            detail: event.detail
        });
        this.dispatchEvent(customEvent);
    }
    handleSubmitChild(event) {
        const customEvent = new CustomEvent('submitsubchild', {
            detail: event.detail
        });
        this.dispatchEvent(customEvent);
    }
    handlenewprofilephoto(event){
        const newevent = new CustomEvent('newprofilephoto', { //resend the event
            detail: event.detail,
            bubbles: true
        });
        this.dispatchEvent(newevent);     
    }

    handleValidationChild (event) {
        const customEvent = new CustomEvent('validationsubchild', {
            detail: {
                validation: event.detail.validation,
                value1: event.detail.value
            }
        });
        this.dispatchEvent(customEvent);
    }
    handleVitalValidationChild (event) {
        const customEvent = new CustomEvent('vitalvalidationsubchild', {
            detail: {
                validation: event.detail.validation,
                value1: event.detail.value
            }
        });
        this.dispatchEvent(customEvent);
    }
    handleVisibleSelfEmp(event) {
        const customEvent = new CustomEvent('visibleselfemployee', {
            detail: event.detail
        });
        this.dispatchEvent(customEvent);         
    }
    handleSubSaveChild (event) {
        const customEvent = new CustomEvent('savesubchild', {
            detail: event.detail
        });
        this.dispatchEvent(customEvent);
    }
    handleSubCancelChild (event) {
        const customEvent = new CustomEvent('cancelsubchild', {
            detail: event.detail
        });
        this.dispatchEvent(customEvent);
    }
    handleSubCurrentSelf (event) {
        const customEvent = new CustomEvent('currentselfemployeesubchild', {
            detail: event.detail
        });
        this.dispatchEvent(customEvent);
    }
    handleExamValue (event) {
        let temp = this.template.querySelector('.class1');
    }
    /* get manageNextANDSAVEButtons () {
        if (this.subPages === 'Social Media') {
            return false;
        }
        return true;
    }   */
   get passObjectName() {
        switch (this.subPages) {
            case 'Vehicles':
                this.objectName = 'Vehicles__r';
                this.childObjectAPIName = 'Vehicle__c';
                break;
            case 'Real Property':
                this.objectName = 'Housing__r';
                this.childObjectAPIName = 'Housing__c';
                break;
            case 'Bank Accounts':
                this.objectName = 'Bank_Investment_Accounts__r';
                this.childObjectAPIName = 'Bank_Account__c';
                break;
            case 'Investment Accounts':
                this.objectName = 'Investment_Account__r';
                this.childObjectAPIName = 'Investment_Account__c';
                break;
            case 'Retirement Accounts':
                this.objectName = 'Retirement_Accounts__r';
                this.childObjectAPIName = 'Retirement_Account__c';
                break;
            case 'Life Insurance':
                this.objectName = 'Life_Insurance__r';
                this.childObjectAPIName = 'Life_Insurance__c';
                break;
            case 'Furniture/Personal Property':
                this.objectName = 'Furniture_Personal_Property__r';
                this.childObjectAPIName = 'Furniture_Personal_Property__c';
                break;
            case 'Additional':
                this.objectName = 'Additional_Assets__r';
                this.childObjectAPIName = 'Additional_Asset__c';
                break;
            case 'Additional Debts':
                this.objectName = 'Debts__r';
                this.childObjectAPIName = 'Debt__c';
                break;
            case 'Credit Cards':
                this.objectName = 'Credit_Card__r';
                this.childObjectAPIName = 'Credit_Card__c';
                break;
            default:
                switch (this.pages) {
                    case 'Debts':
                        this.objectName = 'Credit_Card__r';
                        this.childObjectAPIName = 'Credit_Card__c';
                        break;
                    case 'Income':
                        switch (this.subPages) {
                            case 'Current Employment':
                            case 'Current Self Employment':
                            case 'Previous Employment':
                                this.objectName = 'Employment__r';
                                this.childObjectAPIName = 'Employment__c';
                                break;
                            case 'Income from Benefits':
                            case 'Support Income':
                            case 'Investment Income':
                            case 'Income from Trusts':
                            case 'Rental Income':
                            case 'Other Income':
                                this.objectName = 'Other_Incomes__r';
                                this.childObjectAPIName = 'Other_Income__c';
                                break;
                            case 'Tax Returns':
                                this.objectName = 'Taxes__r';
                                this.childObjectAPIName = 'Taxes__c';
                                break;
                            default:
                                this.objectName = 'Employment__r';
                                break;
                        }
                        break;
                    case 'Expenses':
                        this.objectName = 'Matter__r';
                        this.childObjectAPIName = 'Matters__c';
                        break;
                    default:
                        this.objectName = '';
                        this.childObjectAPIName = '';
                }
        }
        this.fieldsToQuery = CONSTANT.DATA_CONFIG[this.objectName]?.fields || [];
        return this.objectName;
    }
}