import { LightningElement, api, wire, track } from 'lwc';
import { getRecord, getFieldValue, updateRecord } from 'lightning/uiRecordApi';
import { ShowToastEvent } from 'lightning/platformShowToastEvent';
import { refreshApex } from '@salesforce/apex';

import USER_ID from '@salesforce/user/Id';
import ALLOW_FEE_AGREEMENT_FIELD from '@salesforce/schema/Account.Allow_Fee_Agreement__c';
import ACC_CONFLICT_CONFIRMED_BY_FIELD from '@salesforce/schema/Account.Conflict_Check_Confirmed_By__c';
import ACC_CONFIRMATION_DATE_FIELD from '@salesforce/schema/Account.Conflict_Check_Confirmed_On__c';

const ACCOUNT_FIELDS = [
    'Account.Allow_Fee_Agreement__c'
];

export default class ConflictCheckModal extends LightningElement {
    @api recordId;

    @track showModal = false;
    @track isConfirmed = false;
    @track isSaving = false;
    @track errorMessage = '';

    wiredAccountRecord;
    hasInitialized = false;
    previousAllowFeeAgreementValue = null;

    @wire(getRecord, { recordId: '$recordId', fields: ACCOUNT_FIELDS })
    wiredAccount(result) {
        this.wiredAccountRecord = result;

        if (result.data) {
            const allowValue = !!getFieldValue(result.data, ALLOW_FEE_AGREEMENT_FIELD);

            // baseline
            if (!this.hasInitialized) {
                this.previousAllowFeeAgreementValue = allowValue;
                this.hasInitialized = true;
                return;
            }

            // open only on false -> true
            const changedToTrue =
                (this.previousAllowFeeAgreementValue === false && allowValue === true);

            if (changedToTrue && !this.showModal) {
                this.showModal = true;
            }

            this.previousAllowFeeAgreementValue = allowValue;
        } else if (result.error) {
            this.handleError('Error loading account record');
        }
    }

    get isNextDisabled() {
        return !this.isConfirmed || this.isSaving;
    }

    get nextLabel() {
        return this.isSaving ? 'Saving…' : 'Next';
    }

    handleCheckboxChange(event) {
        this.isConfirmed = event.target.checked;
        this.errorMessage = '';
    }

    handleCancel() {
    if (this.isSaving) return;

    this.isSaving = true;       // 🔵 show spinner + disable buttons
    this.errorMessage = '';

    this.resetAllowFeeAgreement()
        .then(() => {
            this.closeModal();
            return this.refreshPage();
        })
        .catch(error => {
            this.isSaving = false;
            this.handleError(
                'Error cancelling confirmation: ' + this.parseError(error)
            );
        });
}


    handleNext() {
        if (this.isSaving) return;

        if (!this.isConfirmed) {
            this.errorMessage = 'Please confirm the checkbox to continue.';
            return;
        }

        this.isSaving = true;
        this.errorMessage = '';

        const fields = {};
        fields.Id = this.recordId;
        fields[ACC_CONFLICT_CONFIRMED_BY_FIELD.fieldApiName] = USER_ID;
        fields[ACC_CONFIRMATION_DATE_FIELD.fieldApiName] = new Date().toISOString();

        updateRecord({ fields })
            .then(() => {
                this.showSuccessToast();
                this.closeModal();
                return this.refreshPage();
            })
            .catch(error => {
                this.isSaving = false;
                this.handleError('Error saving confirmation: ' + this.parseError(error));
            });
    }

    resetAllowFeeAgreement() {
        const fields = {};
        fields.Id = this.recordId;
        fields[ALLOW_FEE_AGREEMENT_FIELD.fieldApiName] = false;
        return updateRecord({ fields }).catch(e => {
            // don’t block UI close, but log it
            console.error('Error resetting allow fee agreement:', e);
        });
    }

    closeModal() {
        this.showModal = false;
        this.isConfirmed = false;
        this.isSaving = false;
        this.errorMessage = '';
    }

    showSuccessToast() {
        this.dispatchEvent(
            new ShowToastEvent({
                title: 'Success',
                message: 'Conflict check confirmed successfully!',
                variant: 'success'
            })
        );
    }

    handleError(message) {
        this.errorMessage = message;
        this.dispatchEvent(
            new ShowToastEvent({
                title: 'Error',
                message,
                variant: 'error'
            })
        );
    }

    parseError(error) {
        return error?.body?.message || error?.message || 'Unknown error occurred';
    }

    refreshPage() {
        return refreshApex(this.wiredAccountRecord);
    }
}