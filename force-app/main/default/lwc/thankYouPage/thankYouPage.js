import { LightningElement, api, track } from 'lwc';
import getAllMatterDetailsForPortalUser from "@salesforce/apex/MatterController.getAllMatterDetailsForPortalUser";
import getAccountDetails from '@salesforce/apex/VitalAccountController.getAccountDetails';
//import mflIcon from '@salesforce/resourceUrl/mflIcon'; // upload as Static Resource
import spinnerPng from '@salesforce/resourceUrl/mflIcon';
const POLL_INTERVAL_MS = 5000;


export default class ThankYouPage extends LightningElement {
    @api recordId;
    @track allMatterCases = [];    
    @track accountDetails;
    @track displayHeader=false;
    //imgUrl = mflIcon;
    imageUrl = spinnerPng;
    connectedCallback() {   
        getAllMatterDetailsForPortalUser().then(result=>{
        this.allMatterCases = result;
        getAccountDetails().then(result=>{ //after allMatterCases is populated
            this.accountDetails=result;
            this.displayHeader=true;  //only after retrieving account and matter detail shoud we display the header
            if (this.allMatterCases && this.allMatterCases.length == 0 && !this.GoldDecision) {
                this.pollForNewMatter();  // start polling for the new matter
            }
            }) .catch(error => {
                createFutureErrorRecord( {exceptionMessage: error.message ?? error.body.message, stackTrace: error.stack ?? error.body.stackTrace, lineNum: 0, errortype: 'Javascript', 
                procname: 'thankYouPage.getAccoutnDetails'}) ;
                console.error('Exception thrown:  ', error, 'stack trace:  ', error.stack);
                });        
            })
        .catch(error => {
            createFutureErrorRecord( {exceptionMessage: error.message ?? error.body.message, stackTrace: error.stack ?? error.body.stackTrace, lineNum: 0, errortype: 'Javascript', 
            procname: 'thankYouPage.getAllMatterDetailsForPortalUser'}) ;
            console.error('Exception thrown:  ', error, 'stack trace:  ', error.stack);
            });     
    }
// ===== POLLING FOR TRUST BALANCE =====
    pollForNewMatter() {
        let pollAttempts=0;
        return new Promise((resolve, reject) => {
            const pollInterval = setInterval(() => {
                pollAttempts++;
                console.log(`pollForNewMatter attempts ${pollAttempts}`);
                getAllMatterDetailsForPortalUser().then(result=>{
                    this.allMatterCases = result;
                })
                .catch(error => {
                    createFutureErrorRecord( {exceptionMessage: error.message ?? error.body.message, stackTrace: error.stack ?? error.body.stackTrace, lineNum: 0, errortype: 'Javascript', 
                    procname: 'thankYouPage.getAllMatterDetailsForPortalUser'}) ;
                    console.error('Exception thrown:  ', error, 'stack trace:  ', error.stack);
                    });     
                if (this.allMatterCases && this.allMatterCases.length >= 1) {
                   clearInterval(pollInterval);  // stop polling for the new matter
                   resolve(this.allMatterCases.length);
                }
            }, POLL_INTERVAL_MS);
        });
    }

    get hasMatter() {
        if (this.allMatterCases && this.allMatterCases.length >= 1) {
            return true;
        }
        return false;
    }    
    get isGoldDecision() {
        if (this.accountDetails?.acc?.Credit_Decision__c?.startsWith('Gold')) {
            return true;
        }
        return false;
    }        

    handleClientInterview() {
            this.dispatchEvent(
                new CustomEvent('continuetointerview', {
                    detail: 'ShowClientInterview',  
                    bubbles: true,
                    composed: true
                })
            );            
        }
}