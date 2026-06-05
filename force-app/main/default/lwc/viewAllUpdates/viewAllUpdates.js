import { LightningElement, wire } from 'lwc';
import getRecentActivities from '@salesforce/apex/PortalActivityController.getRecentActivities';

const FEED_LIMIT = 50;

export default class ViewAllUpdates extends LightningElement {
    items = [];
    isLoading = true;
    loadError = null;

    @wire(getRecentActivities, { limitN: FEED_LIMIT })
    wiredFeed({ data, error }) {
        if (data) {
            this.items = data;
            this.isLoading = false;
            this.loadError = null;
        } else if (error) {
            this.loadError = error.body?.message || error.message || 'Unknown error';
            this.isLoading = false;
        }
    }

    get hasItems() { return !this.isLoading && this.items && this.items.length > 0; }
    get isEmpty() { return !this.isLoading && !this.loadError && (!this.items || this.items.length === 0); }

    handleBack() {
        this.dispatchEvent(new CustomEvent('back', { bubbles: true, composed: true }));
    }
}