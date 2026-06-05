import { LightningElement, wire } from 'lwc';
import { CurrentPageReference } from 'lightning/navigation';
import logo from '@salesforce/resourceUrl/Logo';

export default class Terms extends LightningElement {
    logoImg = logo;
    activeSections = [];

    // Map URL values → accordion section names
    sectionMap = {
        conditions: 'conditions',
        privacy: 'Privacy',
        consumerhealth: 'ConsumerHealth',
        disclaimer: 'Disclaimer',
        cookies: 'Cookies',
        accessibility: 'Accessibility',
        attorneyadvertising: 'Attorney Advertising',
        eeo: 'EEO'
    };

    @wire(CurrentPageReference)
    getStateParameters(currentPageReference) {
        if (currentPageReference) {
            const sectionParam = currentPageReference.state?.section;

            if (sectionParam) {
                const normalized = sectionParam.toLowerCase();
                const sectionName = this.sectionMap[normalized];

                if (sectionName) {
                    this.activeSections = [sectionName];
                }
            }
        }
    }

    handleSectionToggle(event) {
        this.activeSections = event.detail.openSections;
        console.log(this.activeSections);
    }
}