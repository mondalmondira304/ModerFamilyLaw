import { LightningElement, api } from 'lwc';
import getInvoiceRetainerStatus from '@salesforce/apex/timesolvAccFieldChecker.getInvoiceRetainerStatus';
import { ShowToastEvent } from 'lightning/platformShowToastEvent';
import { FlowNavigationNextEvent } from 'lightning/flowSupport';

export default class TsFieldChecker extends LightningElement {
    // Public properties exposed to Flow
    @api recordId;
    @api pollingTimeoutInSeconds = 7;
    @api maxAttemptsInFlow = 10;
    @api successMessage = 'The Timesolv Account is ready. Please proceed to the next step.';
    @api waitingMessage = 'Waiting for Timesolv account to be set...';

    // Private properties
    success = false;
    pollingTimeout;
    maxAttempts;
    currentAttempt = 0;
    intervalId;

    // Lifecycle hooks
    connectedCallback() {
        console.log('LWC connectedCallback - recordId is:', this.recordId);

        // Convert Flow-provided values to appropriate formats
        this.pollingTimeout = this.pollingTimeoutInSeconds * 1000;
        this.maxAttempts = this.maxAttemptsInFlow;

        if (this.recordId) {
            this.startPolling();
        } else {
            this.handleError('No Account ID provided');
        }
    }

    disconnectedCallback() {
        this.clearPollingInterval();
    }

    // Polling methods
    startPolling() {
        // First check immediately
        this.checkFieldValue();

        // Then set up the interval
        this.intervalId = setInterval(() => {
            this.currentAttempt++;

            if (this.currentAttempt >= this.maxAttempts) {
                this.clearPollingInterval();
                this.handleError('Maximum polling attempts reached without success');
                return;
            }

            this.checkFieldValue();
        }, this.pollingTimeout);
    }

    clearPollingInterval() {
        if (this.intervalId) {
            clearInterval(this.intervalId);
            this.intervalId = null;
        }
    }

    // Field checking method
    async checkFieldValue() {
        console.log(`Attempt ${this.currentAttempt + 1}/${this.maxAttempts} - checking field with recordId: ${this.recordId}`);

        try {
            const result = await getInvoiceRetainerStatus({ accountId: this.recordId });
            console.log('Apex returned:', result);

            // If Gold (0% retainer), finish as success
            if (result.isGold) {
                this.success = true;
                this.clearPollingInterval();
                // Optional: display a different message for Gold, or navigate Flow
                // this.dispatchSuccessEvent();
                return;
            }
            // Otherwise, require Invoice Retainer Id to finish
            if (result.invoiceRetainerId) {
                this.success = true;
                this.clearPollingInterval();
                // this.dispatchSuccessEvent();
                return;
            }
            // else, keep polling
        } catch (error) {
            console.error('Error checking Trust Id:', error);
            this.handleError('Error checking field: ' + (error.message || error));
        }
    }

    // Event handlers
    handleError(message) {
        this.dispatchEvent(
            new ShowToastEvent({
                title: 'Error',
                message: message,
                variant: 'error',
            })
        );
    }

    // Optional: not auto-called, but can be used for success feedback
    dispatchSuccessEvent() {
        this.dispatchEvent(
            new ShowToastEvent({
                title: 'Success',
                message: 'Timesolv account has been properly set',
                variant: 'success',
            })
        );
    }

    // Getters for template (if you want to show progress UI)
    get progressPercentage() {
        return Math.floor((this.currentAttempt / this.maxAttempts) * 100);
    }

    get currentAttemptDisplay() {
        return this.currentAttempt + 1;
    }
}