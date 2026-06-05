import { LightningElement, track, api } from 'lwc';
import { FlowNavigationNextEvent } from 'lightning/flowSupport';
import triggerCreditCheck from '@salesforce/apex/TriggerCreditCheckFlowAction.triggerCreditCheck';
import createFutureErrorRecord from '@salesforce/apex/Utility.createFutureErrorRecord';
import getActiveTemplate from '@salesforce/apex/ssConsentController.getActiveTemplate';
import saveConsentWithSnapshot from '@salesforce/apex/ssConsentController.saveConsentWithSnapshot';

export default class ConsentForm extends LightningElement { 
    @track consentChecked = false;
    @track termsChecked = false;
    @api recordId; 
    error;

    consentChecked = false;
    termsChecked = false;
    creditConsentChecked = false;

    // Template state
    templateVersion;
    templateHtml;

      async connectedCallback() {
        try {
            // Load active consent template
            const tpl = await getActiveTemplate();
            if (!tpl || !tpl.Consent_Body__c || !tpl.Version__c) {
                this.errorMsg = 'Active Consent Template is not configured.';
                return;
            }
             this.templateVersion = String(tpl.Version__c);
    const body = tpl.Consent_Body__c;
    this.templateHtml = (body == null) ? '' : String(body);
        } catch (e) {
            // eslint-disable-next-line no-console
            console.error('Init error', e);
            this.errorMsg = 'Failed to initialize consent screen.';
        }
    }

    get buttonDisabled() {
        return !(this.consentChecked && this.termsChecked);
    }

    handleConsentChange(event) {
        this.consentChecked = event.target.checked;
    }
    handleTermsChange(event) {
        this.termsChecked = event.target.checked;        
    }
    handleCreditConsentChange(event) {
        this.creditConsentChecked = event.target.checked;
    }
    get buttonDisabled() {
        return !(this.consentChecked && this.termsChecked && this.creditConsentChecked);
    }

async handleAgree() {
        // clear prior errors
        this.error = null;
        this.errorMsg = '';


        // 1) Validate inputs before doing anything UI/Flow-wise
        if (!this.consentChecked || !this.termsChecked || !this.creditConsentChecked) return;
        if (!this.recordId) { this.errorMsg = 'Account Id is missing.'; return; }
        if (!this.templateVersion) { this.errorMsg = 'Consent template not available.'; return; }

        // 2) Show waiting UI
        this.dispatchEvent(new CustomEvent('simplestart', { detail: 'ShowWaiting' }));

        try {
            // 3) Run the credit check and handle its result
            //    Use accountId consistently (avoid mixing recordId/accountId)
            const creditResult = await triggerCreditCheck({ accountId: this.recordId });
            const { error: creditError, data: creditData } = creditResult || {};

            if (creditError) {
            this.error = creditError;
            this.showToast?.('Error', creditError.message ?? String(creditError), 'error');
            return; // stop; don't save or navigate
            }

            // If your Apex returns a specific shape, enforce it here
            // e.g. if (creditData?.result === 'Error') { this.errorMsg = creditData.message; return; }

            // 4) Save the consent snapshot
            this.isSaving = true;
            await saveConsentWithSnapshot({
            accountId: this.recordId,
            version: this.templateVersion,
            htmlSnapshot: this.templateHtml,
            acceptedDisclosures: this.consentChecked,
            acceptedTerms: this.termsChecked,
            acceptedFCRA: this.creditConsentChecked
            });

            // 5) Navigate only after successful save
            //this.dispatchEvent(new FlowNavigationNextEvent());

        } catch (e) {
            console.error('Consent flow failed', e);
            this.error = e;
            this.errorMsg = 'Could not complete consent. Please try again.';
            this.showToast?.('Error', e.message ?? 'Unexpected error', 'error');
            // If this returns a promise, consider awaiting
            try { createFutureErrorRecord?.(e.message, e.stack, '', '', 'ConsentForm.handleAgree'); } catch {}
        } finally {
            //this.isSaving = false;
            // 6) Always hide waiting UI when done
            //this.dispatchEvent(new CustomEvent('simplestart', { detail: 'HideWaiting' }));
        }
    }

    
}