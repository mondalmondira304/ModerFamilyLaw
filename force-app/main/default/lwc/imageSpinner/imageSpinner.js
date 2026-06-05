import { LightningElement, api } from 'lwc';
import spinnerPng from '@salesforce/resourceUrl/mflIcon'; // upload as Static Resource

export default class ImageSpinner extends LightningElement {
  @api isLoading = false;
  @api alternativeText = 'Loading';
  @api size = 'medium'; // small | medium | large
  @api backdrop = false; // dims background like lightning-spinner

  imageUrl = spinnerPng;

  get containerClass() {
    const base = 'slds-grid slds-grid_align-center slds-grid_vertical-align-center image-spinner';
    return this.backdrop ? `${base} slds-spinner_container slds-is-fixed` : base;
  }

  get imgClass() {
    return `spinner-img ${this.size}`;
  }
}