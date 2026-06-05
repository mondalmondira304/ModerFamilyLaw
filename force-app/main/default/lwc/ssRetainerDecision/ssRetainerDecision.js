import { LightningElement, api, wire } from 'lwc';
import { getRecord, updateRecord } from 'lightning/uiRecordApi';
import { refreshApex } from '@salesforce/apex';
import { ShowToastEvent } from 'lightning/platformShowToastEvent';
import createFutureErrorRecord from "@salesforce/apex/Utility.createFutureErrorRecord";
import getCurrentUserDetail from "@salesforce/apex/MatterController.getCurrentUserDetail";

import CREDIT_DECISION_FIELD from '@salesforce/schema/Account.Credit_Decision__c';
import QUOTED_RETAINER_FIELD from '@salesforce/schema/Account.Quoted_Retainer__c';
import REDUCED_RETAINER_FIELD from '@salesforce/schema/Account.Quoted_Retainer_Amount__c';
import CREDIT_REPORT_FIELD from '@salesforce/schema/Account.Credit_Report_Link__c';
import CREDIT_MESSAGE_FIELD from '@salesforce/schema/Account.Credit_Message__c';
import SIGNING_URL_FIELD from '@salesforce/schema/Account.Fa_Portal_Signing_URL__c';
import SEND_FA_FIELD from '@salesforce/schema/Account.Send_FA__c';
import SHOW_FA_BUTTON from '@salesforce/schema/Account.Allow_Fee_Agreement__c';
import ID_FIELD from '@salesforce/schema/Account.Id';
import NAME_FIELD from '@salesforce/schema/Account.Name';
import STANDARD_RETAINER_FIELD from '@salesforce/schema/Account.Responsible_Attorney__r.Hourly_Billing_Rate__c';

import HEADERIMG from '@salesforce/resourceUrl/ssResultHeaderImg';
import spinnerPng from '@salesforce/resourceUrl/mflIcon'; 

const FIELDS = [
    CREDIT_DECISION_FIELD,
    QUOTED_RETAINER_FIELD,
    REDUCED_RETAINER_FIELD,
    CREDIT_REPORT_FIELD,
    CREDIT_MESSAGE_FIELD,
    NAME_FIELD,
    SIGNING_URL_FIELD,
    SHOW_FA_BUTTON,
    STANDARD_RETAINER_FIELD,
];

const DISCOUNTS = {
    'GOLD - 0% RETAINER': 0,
    'SILVER - 50% RETAINER': 0.5,
    'BRONZE - 80% RETAINER': 0.8
};

// const POLL_INTERVAL_MS = 5000;
// const MAX_POLL_ATTEMPTS = 12; // 12 * 5 seconds = 1 minute total

export default class SsRetainerDecision extends LightningElement {
    @api recordId;

    creditDecision;
    standardRetainerValue;
    quotedRetainer;
    reducedRetainer;
    accountName;
    creditMessage;    
    reportLink;
    signingUrl;    
    headerImg = HEADERIMG;
    imageUrl = spinnerPng;

    wiredAccountResult;
    pollAttempts = 0;
    isPolling = false;
    isProcessing = false;
    showFeeAgreement = false;
    showFeeAgreementButton = false;
    showWaiting = false;

    // ----- Wire Account -----
    @wire(getRecord, { recordId: '$recordId', fields: FIELDS })
    wiredAccount(result) {
        this.wiredAccountResult = result;

        const { data, error } = result;
        if (data) {
            //console.log('stringified data',JSON.stringify(data));
            this.creditDecision   = data.fields.Credit_Decision__c.value;
            this.quotedRetainer   = data.fields.Quoted_Retainer__c.value;
            //this.standardRetainerValue = data.fields.Responsible_Attorney__r?.value?.fields?.Hourly_Billing_Rate__c?.value;
            //        console.log('[DEBUG] standardRetainerValue extracted:', this.standardRetainerValue);
            this.reducedRetainer  = data.fields.Quoted_Retainer_Amount__c.value;
            this.accountName      = data.fields.Name.value;
            this.creditMessage    = data.fields.Credit_Message__c.value;
            this.reportLink       = data.fields.Credit_Report_Link__c.value;
            this.signingUrl       = data.fields.Fa_Portal_Signing_URL__c.value;
            this.showFeeAgreementButton = data.fields.Allow_Fee_Agreement__c.value;            
            console.log('[SsRetainerDecision] Wire updated - signingUrl:', this.signingUrl);       
        } else if (error) {
            console.error('[SsRetainerDecision] getRecord error:', error);
        }
    }

    connectedCallback() {   
        getCurrentUserDetail().then(result=>{ // just to get the hourly billing rate    
            this.standardRetainerValue = result.Responsible_Attorney__r?.Hourly_Billing_Rate__c;
            console.log('[DEBUG] standardRetainerValue extracted:', this.standardRetainerValue);       
        })
        .catch(error => {
        createFutureErrorRecord( {exceptionMessage: error.message ?? error.body.message, stackTrace: error.stack ?? error.body.stackTrace, lineNum: 0, errortype: 'Javascript', 
            procname: 'ssRetainerDecision.connectedCallback()'}) ;
        console.error('Exception thrown:  ', error, 'stack trace:  ', error.stack);
        });
    }

    // ======= GETTERS =======
    get isGoldRetainer() {
        return this.creditDecision === 'Gold - 0% Retainer';
    }

    get hasFeeAgreement() {
        return this.showFeeAgreementButton;
    }

    get hasSigningUrl() {
        return !!this.signingUrl;
    }

    get showMainContent() {
        return !this.showWaiting && !this.showFeeAgreement;
    }

    get isQualified() {
        if (!this.creditDecision) { return false; }
        return Object.keys(DISCOUNTS).includes((this.creditDecision).toUpperCase());
    }
    
    get showValidation() {
        const link = (this.reportLink || '').toLowerCase();
        const msg  = (this.creditMessage || '').toLowerCase();

        const isValidation =
            link.startsWith('failed-400') ||
            msg.includes('invalid') ||
            msg.includes('validation');

        return !this.isQualified && !this.showFrozen && isValidation;
    }

    get showFull() {
        return (
            (this.creditDecision === 'Full Retainer' || (!this.isQualified && !this.showFrozen)) &&
            !this.showValidation
        );
    }

    get showFrozen() {
        return this.creditDecision === 'Credit Frozen';
    }

    get showFailed() {
        return this.creditDecision === 'Failed- Follow up with PC';
    }   

    get creditMessageLines() {
        const raw = (this.creditMessage || '').trim();
        if (!raw) return [];

        const parts = raw
            .split(/(?:\r?\n|;|\.\s+)+/)
            .map(s => s.trim())
            .filter(Boolean);

        return parts.length ? parts : [raw];
    }

    // Calculate standard retainer from discounted if needed
    get standardRetainer() {
        if (this.standardRetainerValue != null) {
        return this.standardRetainerValue * 10;
    }
        if (this.creditDecision === 'GOLD - 0% RETAINER') {
            return 0;
        }
        const discount = DISCOUNTS[this.creditDecision];
        if (discount && this.reducedRetainer) {
            return this.reducedRetainer / discount;
        }
        return this.quotedRetainer != null ? this.quotedRetainer : 0;
    }

    get reducedRetainerDisplay() {
        if (this.creditDecision === 'GOLD - 0% RETAINER') {
            return 0;
        }
        const discount = DISCOUNTS[this.creditDecision];
        if (typeof discount !== 'undefined' && this.standardRetainer) {
            return this.standardRetainer * discount;
        }
        return this.reducedRetainer != null ? this.reducedRetainer : 0;
    }

    get hasStandardTotal() {
        return this.standardTotalAmount !== undefined && this.standardTotalAmount !== null;
    }
    
    get hasDiscountedTotal() {
        return this.discountedTotalAmount !== undefined && this.discountedTotalAmount !== null;
    }

    get percentOff() {
        const std = Number(this.standardRetainer);
        const disc = Number(this.reducedRetainerDisplay);
        if (std > 0 && disc >= 0 && disc <= std) {
            return Math.round(((std - disc) / std) * 100);
        }
        return null;
    }
    
    get hasPercentOff() {
        return this.percentOff !== null;
    }

    handleContinue() {
        this.dispatchEvent(
            new CustomEvent('simplestart', {
                detail: 'ShowFeeAgreementLanding',
                bubbles: true,
                composed: true
            })
        );
    }

    handleGoldOffer(){
        this.dispatchEvent(
            new CustomEvent('simplestart', {
                detail: 'ShowThankYouPage',
                bubbles: true,
                composed: true
            })
        );
    }

    // // ======= POLLING FOR SIGNING URL (PROMISE-BASED) =======
    // async pollForSigningUrlAsync() {
    //     console.log('[SsRetainerDecision] Starting async polling for signing URL...');
        
    //     return new Promise((resolve, reject) => {
    //         // If URL already exists, resolve immediately
    //         if (this.signingUrl) {
    //             console.log('[SsRetainerDecision] Signing URL already present:', this.signingUrl);
    //             resolve(this.signingUrl);
    //             return;
    //         }

    //         this.isPolling = true;
    //         this.pollAttempts = 0;

    //         const pollInterval = setInterval(() => {
    //             // Check if we got the URL
    //             if (this.signingUrl) {
    //                 console.log('[SsRetainerDecision] ✓ Signing URL found:', this.signingUrl);
    //                 clearInterval(pollInterval);
    //                 this.isPolling = false;
    //                 resolve(this.signingUrl);
    //                 return;
    //             }

    //             // Check if max attempts reached
    //             if (this.pollAttempts >= MAX_POLL_ATTEMPTS) {
    //                 console.log('[SsRetainerDecision] ✗ Max polling attempts reached');
    //                 clearInterval(pollInterval);
    //                 this.isPolling = false;
    //                 reject(new Error('Signing URL not available after ' + MAX_POLL_ATTEMPTS + ' attempts'));
    //                 return;
    //             }

    //             // Continue polling
    //             this.pollAttempts++;
    //             console.log(`[SsRetainerDecision] Poll attempt ${this.pollAttempts}/${MAX_POLL_ATTEMPTS}...`);

    //             // Refresh the wired data
    //             if (this.wiredAccountResult) {
    //                 refreshApex(this.wiredAccountResult)
    //                     .then(() => {
    //                         console.log('[SsRetainerDecision] refreshApex completed, signingUrl:', this.signingUrl);
    //                     })
    //                     .catch(error => {
    //                         console.error('[SsRetainerDecision] refreshApex error:', error);
    //                     });
    //             } else {
    //                 console.warn('[SsRetainerDecision] Wire result not available yet');
    //             }
    //         }, POLL_INTERVAL_MS);
    //     });
    // }

    // // ======= REQUEST FEE AGREEMENT CLICK =======
    // async handleFeeAgreement() {
    //     // Prevent multiple clicks
    //     if (this.isProcessing) {
    //         console.log('[SsRetainerDecision] Already processing, please wait...');
    //         return;
    //     }

    //     this.isProcessing = true;
    //     this.showWaiting = true;
    //     this.showFeeAgreement = false;

    //     console.log('[SsRetainerDecision] === Fee Agreement Request Started ===');
    //     console.log('[SsRetainerDecision] Record ID:', this.recordId);

    //     try {
    //         // Step 1: Update Send_FA__c = true
    //         const fields = {};
    //         fields[ID_FIELD.fieldApiName] = this.recordId;
    //         fields[SEND_FA_FIELD.fieldApiName] = true;

    //         console.log('[SsRetainerDecision] Updating Send_FA__c to true...');
    //         await updateRecord({ fields });
    //         console.log('[SsRetainerDecision] ✓ Send_FA__c updated successfully');

    //         // Step 2: Poll for signing URL
    //         console.log('[SsRetainerDecision] Starting to poll for signing URL...');
    //         const signingUrl = await this.pollForSigningUrlAsync();
            
    //         console.log('[SsRetainerDecision] ✓ Signing URL received:', signingUrl);
            
    //         // Step 3: Show fee agreement screen
    //         this.showWaiting = false;
    //         // this.showFeeAgreement = true;
    //         this.dispatchEvent(
    //                 new CustomEvent('simplestart', {
    //                     detail: 'ShowFeeAgreementLanding',
    //                     bubbles: true,
    //                     composed: true
    //                 })
    //             );
            
    //         console.log('[SsRetainerDecision] === Fee Agreement Request Completed ===');

    //     } catch (error) {
    //         console.error('[SsRetainerDecision] ✗ Error in handleFeeAgreement:', error);
            
    //         // Hide waiting, show error
    //         this.showWaiting = false;
    //         this.showFeeAgreement = false;
            
    //         // Show error toast
    //         this.dispatchEvent(
    //             new ShowToastEvent({
    //                 title: 'Error',
    //                 message: error.message || 'Failed to request fee agreement. Please try again or contact support.',
    //                 variant: 'error',
    //                 mode: 'sticky'
    //             })
    //         );
    //     } finally {
    //         this.isProcessing = false;
    //     }
    // }

    // Back button handler
    handleBackToDecision() {
        this.showFeeAgreement = false;
        this.showWaiting = false;
    }
}