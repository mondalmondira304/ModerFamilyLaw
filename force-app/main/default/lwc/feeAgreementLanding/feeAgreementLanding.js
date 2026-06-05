import { LightningElement, api, wire, track } from 'lwc';
import { getRecord, updateRecord } from 'lightning/uiRecordApi';
import { refreshApex } from '@salesforce/apex';
import { ShowToastEvent } from 'lightning/platformShowToastEvent';
import updateAccount from '@salesforce/apex/VitalAccountController.updateAccount';

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
];

const POLL_INTERVAL_MS = 5000;
const MAX_POLL_ATTEMPTS = 24; // 24 * 5 seconds = 2 minute total

export default class FeeAgreementLanding extends LightningElement {

    @api recordId;
    @track agreeChecked = false;
    
    creditDecision;
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

    agreeChecked = false;

    sendFAFlag;

    // ----- Wire Account -----
    @wire(getRecord, { recordId: '$recordId', fields: FIELDS })
    wiredAccount(result) {
        this.wiredAccountResult = result;

        const { data, error } = result;
        if (data) {
            this.creditDecision   = data.fields.Credit_Decision__c.value;
            this.quotedRetainer   = data.fields.Quoted_Retainer__c.value;
            this.reducedRetainer  = data.fields.Quoted_Retainer_Amount__c.value;
            this.accountName      = data.fields.Name.value;
            this.creditMessage    = data.fields.Credit_Message__c.value;
            this.reportLink       = data.fields.Credit_Report_Link__c.value;
            this.signingUrl       = data.fields.Fa_Portal_Signing_URL__c.value;
            this.showFeeAgreementButton = data.fields.Allow_Fee_Agreement__c.value;
           // this.checkTrustBalanceFlag = data.fields[CHECK_TRUST_BALANCE.fieldApiName]?.value;
            
            console.log('[SsRetainerDecision] Wire updated - signingUrl:', this.signingUrl);
        } else if (error) {
            console.error('[SsRetainerDecision] getRecord error:', error);
        }
    }

    get hasSigningUrl() {
        return !!this.signingUrl;
    }

    get showMainContent() {
        return !this.showWaiting && !this.showFeeAgreement;
    }

    get buttonDisabled() {
        return !(this.agreeChecked);
    }

    handleAgreeChange(event) {
        this.agreeChecked = event.target.checked;
    }

    // ======= POLLING FOR SIGNING URL (PROMISE-BASED) =======
    async pollForSigningUrlAsync() {
        console.log('[SsRetainerDecision] Starting async polling for signing URL...');
        
        return new Promise((resolve, reject) => {
            // If URL already exists, resolve immediately
            if (this.signingUrl) {
                console.log('[SsRetainerDecision] Signing URL already present:', this.signingUrl);
                resolve(this.signingUrl);
                return;
            }

            this.isPolling = true;
            this.pollAttempts = 0;

            const pollInterval = setInterval(() => {
                // Check if we got the URL
                if (this.signingUrl) {
                    console.log('[SsRetainerDecision] ✓ Signing URL found:', this.signingUrl);
                    clearInterval(pollInterval);
                    this.isPolling = false;
                    resolve(this.signingUrl);
                    return;
                }

                // Check if max attempts reached
                if (this.pollAttempts >= MAX_POLL_ATTEMPTS) {
                    console.log('[SsRetainerDecision] ✗ Max polling attempts reached');
                    clearInterval(pollInterval);
                    this.isPolling = false;
                    reject(new Error('Signing URL not available after ' + MAX_POLL_ATTEMPTS + ' attempts'));
                    return;
                }

                // Continue polling
                this.pollAttempts++;
                console.log(`[SsRetainerDecision] Poll attempt ${this.pollAttempts}/${MAX_POLL_ATTEMPTS}...`);

                // Refresh the wired data
                if (this.wiredAccountResult) {
                    refreshApex(this.wiredAccountResult)
                        .then(() => {
                            console.log('[SsRetainerDecision] refreshApex completed, signingUrl:', this.signingUrl);
                        })
                        .catch(error => {
                            console.error('[SsRetainerDecision] refreshApex error:', error);
                        });
                } else {
                    console.warn('[SsRetainerDecision] Wire result not available yet');
                }
            }, POLL_INTERVAL_MS);
        });
    }

    // ======= REQUEST FEE AGREEMENT CLICK =======
    async handleFeeAgreement() {

        if (!this.agreeChecked ) return;

        // Prevent multiple clicks
        if (this.isProcessing) {
            console.log('[SsRetainerDecision] Already processing, please wait...');
            return;
        }

        this.isProcessing = true;
        this.showWaiting = true;
        this.showFeeAgreement = false;

        console.log('[SsRetainerDecision] === Fee Agreement Request Started ===');
        console.log('[SsRetainerDecision] Record ID:', this.recordId);

        try {

            // if (this.sendFAFlag !== false) {
            //     console.log('[SsRetainerDecision] Resetting Send_FA__c to FALSE...');

            //     await updateAccount({ 
            //         acc: { Id: this.recordId, Send_FA__c: false }
            //     });
            // }

            // console.log('[SsRetainerDecision] Updating Send_FA__c to true...');

            await updateAccount({
                acc: { Id: this.recordId, Send_FA__c: true }
            });
            console.log('[SsRetainerDecision] ✓ Send_FA__c updated successfully');

            // acct['Id']=this.recordId  ;  //populated from the wire adapter but is known by the parent component already
            // acct['Send_FA__c']=true;
            // updateAccount({ acc: acct }); // to bypass sharing rules  

            // Step 2: Poll for signing URL
            console.log('[SsRetainerDecision] Starting to poll for signing URL...');
            const signingUrl = await this.pollForSigningUrlAsync();
            
            console.log('[SsRetainerDecision] ✓ Signing URL received:', signingUrl);
            
            // Step 3: Show fee agreement screen
            this.showWaiting = false;
            // this.showFeeAgreement = true;
            this.dispatchEvent(
                    new CustomEvent('simplestart', {
                        detail: 'ShowFeeAgreement',
                        bubbles: true,
                        composed: true
                    })
                );
            
            console.log('[SsRetainerDecision] === Fee Agreement Request Completed ===');

        } catch (error) {
            console.error('[SsRetainerDecision] ✗ Error in handleFeeAgreement:', error);
            
            // Hide waiting, show error
            this.showWaiting = false;
            this.showFeeAgreement = false;
            
            // Show error toast
            this.dispatchEvent(
                new ShowToastEvent({
                    title: 'Error',
                    message: error.message || 'Failed to request fee agreement. Please try again or contact support.',
                    variant: 'error',
                    mode: 'sticky'
                })
            );
        } finally {
            this.isProcessing = false;
        }
    }
}