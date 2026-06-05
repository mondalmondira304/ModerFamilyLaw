import { LightningElement, api, wire } from 'lwc';
import { getRecord } from 'lightning/uiRecordApi';
import { refreshApex } from '@salesforce/apex';
import { ShowToastEvent } from 'lightning/platformShowToastEvent';

import CREDIT_DECISION_FIELD from '@salesforce/schema/Account.Credit_Decision__c';
import SIGNING_URL_FIELD from '@salesforce/schema/Account.Fa_Portal_Signing_URL__c';
import AGREEMENT_STATUS_FIELD from '@salesforce/schema/Account.FA_Portal_Agreement_Status__c';

import spinnerPng from '@salesforce/resourceUrl/mflIcon'; 

const FIELDS = [CREDIT_DECISION_FIELD, SIGNING_URL_FIELD, AGREEMENT_STATUS_FIELD];

const POLL_INTERVAL_MS = 5000;
const MAX_POLL_ATTEMPTS = 12; // 1 minute total

// Statuses that should block moving forward
const BLOCKING_STATUSES = [
    'Out for Signature',
    'Out of Signature',
    'Cancelled',
    'Expired'
];

export default class FeeAgreement extends LightningElement {
    @api recordId;

    creditDecision;
    signingUrl;
    agreementStatus;

    wiredAccountResult;
    pollAttempts = 0;
    isPolling = false;
    showWaiting = false;

    showNotSigned = false;

    imageUrl = spinnerPng;

    onMessage;

    // ===== WIRE ACCOUNT =====
    @wire(getRecord, { recordId: '$recordId', fields: FIELDS })
    wiredAccount(result) {
        this.wiredAccountResult = result;
        const { data, error } = result;

        if (data) {
            this.creditDecision =
                data.fields[CREDIT_DECISION_FIELD.fieldApiName]?.value;
            this.signingUrl =
                data.fields[SIGNING_URL_FIELD.fieldApiName]?.value;
            this.agreementStatus =
                data.fields[AGREEMENT_STATUS_FIELD.fieldApiName]?.value;

            console.log('[FeeAgreement] creditDecision:', this.creditDecision);
            console.log('[FeeAgreement] signingUrl:', this.signingUrl);
            console.log('[FeeAgreement] agreementStatus:', this.agreementStatus);
        } else if (error) {
            console.error('[FeeAgreement] wiredAccount error:', error);
        }
    }

    connectedCallback() {
        this.onMessage = (event) => {
            const allowed = [
                'https://secure.echosign.com',
                'https://secure.na3.echosign.com',
                'https://secure.na3.adobesign.com'
            ];
            if (!allowed.includes(event.origin)) return;

            // 2) Parse the payload
            let msg = event.data;
            if (typeof msg === 'string') {
                try { msg = JSON.parse(msg); } catch (e) { return; }
            }

            // 3) React to events (ESIGN is the big one)
            const eventType = msg?.eventType || msg?.type;
            if (eventType === 'ESIGN') {
                this.showWaiting = true;
                console.log('Signed');
                this.handlePaymentLink();
            }
            if (eventType === 'REJECT') {
                this.showNotSigned = true;
            }
        };

        window.addEventListener('message', this.onMessage);
    }

    disconnectedCallback() {
        window.removeEventListener('message', this.onMessage);
    }


    // ===== GETTERS =====
    get isGoldRetainer() {
        return this.creditDecision === 'Gold - 0% Retainer';
    }

    get hasSigningUrl() {
        return !!this.signingUrl;
    }

    get isAgreementBlocked() {
        return BLOCKING_STATUSES.includes(this.agreementStatus);
    }

    // ===== POLL FOR AGREEMENT STATUS TO CHANGE =====
    pollForAgreementStatusAsync() {
        console.log('[FeeAgreement] Starting async polling for agreement status...');

        return new Promise((resolve, reject) => {
            // If already not blocked, resolve immediately
            if (this.agreementStatus && !this.isAgreementBlocked) {
                console.log(
                    '[FeeAgreement] Agreement already in allowed status:',
                    this.agreementStatus
                );
                resolve(this.agreementStatus);
                return;
            }

            this.pollAttempts = 0;

            const pollInterval = setInterval(() => {
                // If status has moved to allowed state, stop and resolve
                if (this.agreementStatus && !this.isAgreementBlocked) {
                    console.log(
                        '[FeeAgreement] ✓ Agreement status now allowed:',
                        this.agreementStatus
                    );
                    clearInterval(pollInterval);
                    resolve(this.agreementStatus);
                    return;
                }

                // Max attempts?
                if (this.pollAttempts >= MAX_POLL_ATTEMPTS) {
                    console.log('[FeeAgreement] ✗ Max polling attempts reached');
                    clearInterval(pollInterval);
                    reject(
                        new Error(
                            'Agreement was not signed within the expected time.'
                        )
                    );
                    return;
                }

                this.pollAttempts++;
                console.log(
                    `[FeeAgreement] Poll attempt ${this.pollAttempts}/${MAX_POLL_ATTEMPTS}...`
                );

                // Refresh the wired record
                if (this.wiredAccountResult) {
                    refreshApex(this.wiredAccountResult)
                        .then(() => {
                            console.log(
                                '[FeeAgreement] refreshApex, agreementStatus:',
                                this.agreementStatus
                            );
                        })
                        .catch((error) => {
                            console.error(
                                '[FeeAgreement] refreshApex error:',
                                error
                            );
                        });
                }
            }, POLL_INTERVAL_MS);
        });
    }

    // ===== HANDLE PAYMENT LINK CLICK =====
    async handlePaymentLink() {

        this.showWaiting = true;
        this.showNotSigned = false;
        console.log('showWaiting is now:', this.showWaiting);
        console.log('[FeeAgreement] handlePaymentLink clicked');

        // Prevent double clicks while we’re already waiting
        if (this.isPolling) {
            console.log('[FeeAgreement] Already polling for agreement status...');
            return;
        }

        // If already allowed, just proceed
        if (!this.isAgreementBlocked) {
            this.navigateToPayment();
            return;
        }

        // Otherwise, wait for the user to finish signing
        this.isPolling = true;

        try {
            const finalStatus = await this.pollForAgreementStatusAsync();
            console.log('[FeeAgreement] Final agreement status:', finalStatus);

            // if (this.isAgreementBlocked) {
            //     // Shouldn’t happen unless it flips back or never changed
            //     this.dispatchEvent(
            //         new ShowToastEvent({
            //             title: 'Agreement Not Ready',
            //             message:
            //                 'The fee agreement is not fully signed yet. Please complete signing before proceeding to payment.',
            //             variant: 'warning',
            //             mode: 'sticky'
            //         })
            //     );
            //     return;
            // }

            // Now it’s safe to go forward

            if (this.creditDecision === 'Gold - 0% Retainer') {
                this.handleGoldThankYou();
            } else {
                this.navigateToPayment();
            }

        } catch (error) {

            this.showWaiting = false;
            console.error('[FeeAgreement] Error while waiting for signature:', error);

            this.showNotSigned = true;

            // this.dispatchEvent(
            //     new ShowToastEvent({
            //         title: 'Agreement Not Signed',
            //         message:
            //             error.message ||
            //             'The agreement was not signed in time. Please complete signing before continuing.',
            //         variant: 'warning',
            //         mode: 'sticky'
            //     })
            // );
        } finally {
            this.isPolling = false;
            this.showWaiting = false;
        }
    }

    // ===== NAV HELPERS =====
    navigateToPayment() {
        this.dispatchEvent(
            new CustomEvent('simplestart', {
                detail: 'ShowPaymentLink',
                bubbles: true,
                composed: true
            })
        );
    }

    handleGoldThankYou() {
        this.dispatchEvent(
            new CustomEvent('simplestart', {
                detail: 'ShowThankYouPage',
                bubbles: true,
                composed: true
            })
        );
    }
}