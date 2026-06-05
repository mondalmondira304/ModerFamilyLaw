// waitingForCreditResults.js
import { LightningElement, api, wire } from 'lwc';
import { FlowNavigationNextEvent } from 'lightning/flowSupport';
import { getRecord, getFieldValue } from 'lightning/uiRecordApi';
import { refreshApex } from '@salesforce/apex';
import CREDIT_DECISION_FIELD from '@salesforce/schema/Account.Credit_Decision__c';

export default class WaitingForCreditResult extends LightningElement {
  @api recordId;

  isLoading = true;            // ⟵ show spinner immediately
  wiredAccountResult;
  intervalId;
  hasNavigated = false;

  @wire(getRecord, { recordId: '$recordId', fields: [CREDIT_DECISION_FIELD] })
  wiredAccount(result) {
    this.wiredAccountResult = result;
    const { data, error } = result;
    if (data) {
      const creditDecision = getFieldValue(data, CREDIT_DECISION_FIELD);
      if (creditDecision && !this.hasNavigated) {
        this.stopPollingAndNavigate();
      }
    } else if (error) {
      console.error('Error wiring record:', error);
      this.isLoading = false;   // ⟵ stop spinner on error
      this.stopPolling();
    }
  }

  connectedCallback() {
    this.intervalId = setInterval(() => {
      if (this.wiredAccountResult) {
        refreshApex(this.wiredAccountResult);
      }
    }, 3000);
  }

  disconnectedCallback() {
    this.stopPolling();
    this.isLoading = false;     // ⟵ cleanup
  }

  stopPolling() {
    if (this.intervalId) {
      clearInterval(this.intervalId);
      this.intervalId = null;
    }
  }

  stopPollingAndNavigate() {
    if (!this.hasNavigated) {
      this.hasNavigated = true;
      this.isLoading = false;   // ⟵ hide spinner before moving on
      this.stopPolling();
      this.dispatchEvent(new FlowNavigationNextEvent());
      this.dispatchEvent(new CustomEvent('simplestart', { detail: 'ShowRetainerDecision' }));
    }
  }
}