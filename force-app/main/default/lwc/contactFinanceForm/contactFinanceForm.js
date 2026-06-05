import { api } from 'lwc';
import LightningModal from 'lightning/modal';
import sendFinanceMessage from '@salesforce/apex/FinanceMessageController.sendFinanceMessage';

/**
 * ContactFinanceForm — opened via ContactFinanceForm.open({ account, matters }).
 * Submitting calls FinanceMessageController.sendFinanceMessage which emails the
 * finance team and logs a Task on the client's Account.
 */
export default class ContactFinanceForm extends LightningModal {
    // Inputs passed in via .open({ ... })
    @api account;
    @api matters;

    // Form state
    subject = '';
    message = '';
    matterId = '';

    isSubmitting = false;
    errorMessage = '';

    // ── Derived ─────────────────────────────────────────────────────
    get clientName() { return this.account?.Name || ''; }
    get clientEmail() { return this.account?.PersonEmail || ''; }

    get matterOptions() {
        const base = [{ label: 'General inquiry (not matter-specific)', value: '' }];
        if (!Array.isArray(this.matters)) return base;
        return base.concat(this.matters.map(m => ({
            label: m.Case_Type__c
                ? `${m.Case_Type__c}${m.Matter_ID_Full__c ? ' — ' + m.Matter_ID_Full__c : ''}`
                : (m.Matter_ID_Full__c || 'Matter'),
            value: m.Id
        })));
    }

    get canSubmit() {
        return !this.isSubmitting
            && this.subject.trim().length > 0
            && this.message.trim().length > 0;
    }

    // ── Handlers ────────────────────────────────────────────────────
    handleMatterChange(event) { this.matterId = event.detail.value; }
    handleSubjectChange(event) { this.subject = event.target.value; }
    handleMessageChange(event) { this.message = event.target.value; }

    handleCancel() {
        this.close('cancel');
    }

    handleSubmit() {
        if (!this.canSubmit) return;
        this.isSubmitting = true;
        this.errorMessage = '';

        sendFinanceMessage({
            form: {
                subject: this.subject.trim(),
                message: this.message.trim(),
                matterId: this.matterId || ''
            }
        })
            .then(() => {
                this.close('sent');
            })
            .catch(error => {
                this.errorMessage = error?.body?.message || error?.message || 'Could not send your message.';
                this.isSubmitting = false;
            });
    }
}