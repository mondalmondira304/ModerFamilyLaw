import { LightningElement, api, wire } from 'lwc';
import { getRecord, getFieldValue } from 'lightning/uiRecordApi';

// Matter fields
import ACCOUNT_ID_FIELD              from '@salesforce/schema/Matters__c.Account__c';
import RETAINER_AMOUNT_FIELD         from '@salesforce/schema/Matters__c.Retainer_Amount__c';
// pull FA amount from Client Quoted_Retainer__c
import CLIENT_QUOTED_RETAINER_FIELD  from '@salesforce/schema/Matters__c.Client_Name__r.Quoted_Retainer__c';

// Apex
import getWidgetForMatter from '@salesforce/apex/TSFinanceWidgetController.getWidgetForMatter';

const MATTER_FIELDS = [ACCOUNT_ID_FIELD, RETAINER_AMOUNT_FIELD, CLIENT_QUOTED_RETAINER_FIELD];

export default class MatterFinancialWidget extends LightningElement {
    @api recordId;

    // sources
    matter;
    widget;

    // ui state
    debugAccountId;
    isLoading = false;
    hasError = false;
    errorMessage = '';

    /* ------------------ Matter (for Retainer + Account) ------------------ */
    @wire(getRecord, { recordId: '$recordId', fields: MATTER_FIELDS })
    wiredMatter({ data, error }) {
        this.isLoading = true;
        this.hasError = false;
        this.errorMessage = '';

        if (error) {
            this.hasError = true;
            this.errorMessage = 'Error loading Matter: ' + JSON.stringify(error);
            this.matter = undefined;
            console.error('wiredMatter error', error);
        } else if (data) {
            this.matter = data;
            this.debugAccountId = getFieldValue(data, ACCOUNT_ID_FIELD);
        }
        this.isLoading = false;
    }

    /* ------------------ Widget (TimeSolv totals + Trust) ------------------ */
    @wire(getWidgetForMatter, { matterId: '$recordId' })
    wiredWidget({ data, error }) {
        this.isLoading = true;

        if (error) {
            this.hasError = true;
            this.errorMessage = 'Error loading TS Finance Widget: ' + JSON.stringify(error);
            this.widget = undefined;
            console.error('wiredWidget error', error);
        } else if (data) {
            this.widget = data;
        }
        this.isLoading = false;
    }

    /* ------------------ Raw values ------------------ */
    get trustBalance() {
        return Number(this.widget?.Timesolv_Trust_Balance__c || 0);
    }

    get wip() {
        const fees = Number(this.widget?.Timesolv_Total_WIP_Fees__c || 0);
        const exp  = Number(this.widget?.Timesolv_Total_WIP_Expenses__c || 0);
        return fees + exp;
    }

    get worked() {
        const fees = Number(this.widget?.Timesolv_Total_Fees__c || 0);
        const exp  = Number(this.widget?.Timesolv_Total_Expenses__c || 0);
        return fees + exp;
    }

    get billed() {
        return this.worked - this.wip;
    }

    get retainerAmount() {
    const quoted = getFieldValue(this.matter, CLIENT_QUOTED_RETAINER_FIELD);
    return Number(quoted || 0);
}


    /* ------------------ Balance/Credit logic ------------------ */
    get chargesToCoverNow() { return this.wip; }

    get retainerShortfall() {
        const diff = this.retainerAmount - this.trustBalance;
        return diff > 0 ? diff : 0;
    }

    get payToMaintainRetainer() { return this.retainerShortfall; }

    get totalBalanceDue() { 
        return this.chargesToCoverNow + this.retainerShortfall; 
    }

    /* ------------------ Action bar bindings ------------------ */
    get showTotalPotentialDue() {
        const trustIsLow = this.trustBalance < this.retainerAmount;
        const hasWip = this.wip > 0;
        return trustIsLow && hasWip;
    }

    get payToMaintainRetainerFormatted() { return this.formatCurrency(this.payToMaintainRetainer); }
    get formattedTotalBalanceDue() { return this.formatCurrency(this.totalBalanceDue); }

    /* ------------------ Summary box bindings ------------------ */
    get trustVsWipLabel() {
        return 'Total Balance Due';
    }
    get formattedTrustVsWip() {
        return this.formatCurrency(this.totalBalanceDue);
    }

    /* ------------------ Last Synced Timestamp ------------------ */
    get formattedLastSync() {
        if (!this.widget || !this.widget.LastModifiedDate) {
            return 'Not yet synced';
        }
        const dt = new Date(this.widget.LastModifiedDate);
        return dt.toLocaleString(undefined, {
            month: 'short',
            day: 'numeric',
            hour: '2-digit',
            minute: '2-digit'
        });
    }

    /* ------------------ Formatting ------------------ */
    formatCurrency(v) {
        return `$${Number(v || 0).toLocaleString(undefined, { minimumFractionDigits: 2, maximumFractionDigits: 2 })}`;
    }
    get formattedRetainerAmount()  { return this.formatCurrency(this.retainerAmount); }
    get formattedTrustBalance()    { return this.formatCurrency(this.trustBalance); }
    get formattedWip()             { return this.formatCurrency(this.wip); }
    get formattedWorked()          { return this.formatCurrency(this.worked); }
    get formattedBilled()          { return this.formatCurrency(this.billed); }

    get debugAccountIdValue() { return this.debugAccountId; }
}