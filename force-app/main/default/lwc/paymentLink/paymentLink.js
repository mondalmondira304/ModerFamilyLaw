import { LightningElement, api, wire } from 'lwc';
import { getRecord, updateRecord } from 'lightning/uiRecordApi';
import { refreshApex } from '@salesforce/apex';
import { ShowToastEvent } from 'lightning/platformShowToastEvent';
import updateAccount from '@salesforce/apex/VitalAccountController.updateAccount';

import ID_FIELD from '@salesforce/schema/Account.Id';
import INVOICE_RETAINER_URL from '@salesforce/schema/Account.Invoice_Retainer_URL__c';
import CHECK_TRUST_BALANCE from '@salesforce/schema/Account.Check_Trust_Balance__c';
import TRUST_BALANCE from '@salesforce/schema/Account.Timesolv_TrustAccount_Balance__c';
import FEE_AGREEMENT_AMOUNT from '@salesforce/schema/Account.Total_Fee_Agreement_Amount__c';

import spinnerPng from '@salesforce/resourceUrl/mflIcon';

const FIELDS = [INVOICE_RETAINER_URL, CHECK_TRUST_BALANCE, TRUST_BALANCE, FEE_AGREEMENT_AMOUNT];

const POLL_INTERVAL_MS = 3000;
const MAX_POLL_ATTEMPTS = 5; 
export default class PaymentLink extends LightningElement {
    @api recordId;

    invoiceRetainerUrl;
    checkTrustBalanceFlag;
    trustBalance;
    feeAgreementAmount;

    wiredAccountResult;
    pollAttempts = 0;
    isPolling = false;
    isProcessing = false;
    showWaiting = false;
    showNotPaid = false;

    isLoading = false;
    isPaymentLanding = true;

    paymentCompleteChecked = false;

    imageUrl = spinnerPng;

    // init guards
    hasInitialized = false;
    hasWireData = false;

    // start ASAP, but don’t run twice
    connectedCallback() {
        // Don’t actually run the check here yet—wire may not be ready.
        // We’ll trigger once we receive wire data (see wiredAccount).
        console.log('[PaymentLink] connectedCallback');
    }

    @wire(getRecord, { recordId: '$recordId', fields: FIELDS })
    wiredAccount(result) {
        this.wiredAccountResult = result; // needed for refreshApex
        const { data, error } = result;

        if (data) {
            this.invoiceRetainerUrl = data.fields[INVOICE_RETAINER_URL.fieldApiName]?.value;
            this.trustBalance = data.fields[TRUST_BALANCE.fieldApiName]?.value;
            this.checkTrustBalanceFlag = data.fields[CHECK_TRUST_BALANCE.fieldApiName]?.value;
            this.feeAgreementAmount = data.fields[FEE_AGREEMENT_AMOUNT.fieldApiName]?.value;

            this.hasWireData = true;

            console.log('[PaymentLink] wiredAccount trustBalance:', this.trustBalance);
            console.log('[PaymentLink] wiredAccount checkTrustBalanceFlag:', this.checkTrustBalanceFlag);

            // auto-run once, before showing page content
            if (!this.hasInitialized) {
                this.hasInitialized = true;
                // Fire and forget, but keep error handling inside the function
                // this.handleCheckTrustBalance();
                this.handlePayentLanding();
            }
        } else if (error) {
            console.error('[PaymentLink] wiredAccount error:', error);
        }
    }

    // ===== POLLING FOR TRUST BALANCE =====
    pollForTrustBalanceAsync() {
        console.log('[PaymentLink] Starting async polling for trust balance...');

        return new Promise((resolve, reject) => {
            this.isPolling = true;
            this.pollAttempts = 0;

            const pollInterval = setInterval(() => {
                // Stop if max attempts reached
                if (this.pollAttempts >= MAX_POLL_ATTEMPTS) {
                    console.log('[PaymentLink] ✗ Max polling attempts reached');
                    clearInterval(pollInterval);
                    this.isPolling = false;
                    reject(new Error('Trust balance not available after ' + MAX_POLL_ATTEMPTS + ' attempts'));
                    return;
                }

                this.pollAttempts++;
                console.log(`[PaymentLink] Poll attempt ${this.pollAttempts}/${MAX_POLL_ATTEMPTS}... current:`, this.trustBalance);

                if (!this.wiredAccountResult) {
                    console.warn('[PaymentLink] Wire result not available yet');
                    return;
                }

                // Refresh first, THEN decide
                refreshApex(this.wiredAccountResult)
                    .then(() => {
                        const balance = this.trustBalance;

                        // ✅ If the balance is now known (including 0), stop polling
                        if (balance !== null && balance !== undefined) {
                            console.log('[PaymentLink] ✓ Trust balance resolved:', balance);
                            clearInterval(pollInterval);
                            this.isPolling = false;
                            resolve(Number(balance));
                        }
                    })
                    .catch((error) => {
                        console.error('[PaymentLink] refreshApex error:', error);
                    });

            }, POLL_INTERVAL_MS);
        });
    }

    handlePayentLanding() {
        // this.isPaymentLanding = true;
        this.handleCheckTrustBalance();
    }

    handleContinueToPayment(){
        this.isPaymentLanding = false;
    }

    get buttonDisabled() {
        return !(this.paymentCompleteChecked);
    }

    handlePaymentComplete(event) {
        this.paymentCompleteChecked = event.target.checked;
    }



    async handleCheckTrustBalance() {
        console.log('[PaymentLink] handleCheckTrustBalance (auto)');

    
        this.showWaiting = true;
        this.showNotPaid = false;

        if (this.isProcessing) {
            console.log('[PaymentLink] Already processing, please wait...');
            return;
        }

        if (!this.isPaymentLanding) {
            this.isProcessing = true;
        }


        try {
            
            if (this.checkTrustBalanceFlag !== false) {
                console.log('[PaymentLink] Resetting Check_Trust_Balance__c to FALSE...');
                await updateAccount({
                    acc: { Id: this.recordId, Check_Trust_Balance__c: false, Timesolv_TrustAccount_Balance__c: null }

                });
            }
            
            console.log('[PaymentLink] Setting Check_Trust_Balance__c to TRUE...');
            await updateAccount({
                acc: { Id: this.recordId, Check_Trust_Balance__c: true }
            });

            console.log('[PaymentLink] ✓ Check_Trust_Balance__c toggled successfully');

            console.log('[PaymentLink] Starting to poll for trust balance...');
            const balance = await this.pollForTrustBalanceAsync();

            console.log('[PaymentLink] ✓ Trust balance received:', balance);

            if (balance === 0) {
                // show main page content immediately
                this.isWaiting = false;
                this.showWaiting = false;
                this.showNotPaid = false; // or true, depending on what 0 means
                return;
            }

            if (this.feeAgreementAmount === null || this.feeAgreementAmount === undefined) {
                throw new Error('Fee Agreement Amount is not available yet.');
            }

            if (this.hasSufficientAmount(balance, this.feeAgreementAmount)) {
                console.log('Balance is sufficient');
                this.handleThankYou();
            } else {
                console.log('Amounts are not equal');
                this.showWaiting = false;
                this.showNotPaid = true;
            }
        } catch (error) {
            this.showWaiting = false;
            console.error('[PaymentLink] ✗ Error in handleCheckTrustBalance:', error);

            if (error.body) {
                console.error('[PaymentLink] error.body:', JSON.stringify(error.body, null, 2));
            }

            this.dispatchEvent(
                new ShowToastEvent({
                    title: 'Error',
                    message:
                        error.body?.message ||
                        error.message ||
                        'Failed to check trust balance. Please try again or contact support.',
                    variant: 'error',
                    mode: 'sticky'
                })
            );
        } finally {
            this.isProcessing = false;
            this.showWaiting = false;
        }
    }

    hasSufficientAmount(a, b) {
        if (a === null || a === undefined || b === null || b === undefined) return false;

        const numA = Number(a);
        const numB = Number(b);
        if (Number.isNaN(numA) || Number.isNaN(numB)) return false;

        const EPSILON = 0.01;
        return numA > numB || Math.abs(numA - numB) < EPSILON;
    }

    handleGoToTimesolv() {
        if (this.invoiceRetainerUrl) {
            window.open(this.invoiceRetainerUrl, '_blank', 'noopener,noreferrer');
        }
    }


    handleThankYou() {
        this.dispatchEvent(
            new CustomEvent('simplestart', {
                detail: 'ShowThankYouPage',
                bubbles: true,
                composed: true
            })
        );
    }
}