import { LightningElement } from 'lwc';

export default class ssLandingPage extends LightningElement {

    handleStartApplication(event) {
               
         // Proceed to next Flow screen
        this.dispatchEvent(new CustomEvent("simplestart", { detail: 'ShowSimpleStartApplication' }));           
    }
}