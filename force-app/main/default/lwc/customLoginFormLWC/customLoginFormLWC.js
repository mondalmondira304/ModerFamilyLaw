import { LightningElement, track, api, wire } from 'lwc';
import forgotPassword from '@salesforce/apex/LightningForgotPasswordController.forgotPassword';
import getLoginSettings from '@salesforce/apex/LightningLoginFormController.getLoginSettings';
import login from '@salesforce/apex/LightningLoginFormController.login';
import logo from '@salesforce/resourceUrl/Logo';
import loginGradient from '@salesforce/resourceUrl/loginFormGradient';
import customLoginBackground from '@salesforce/resourceUrl/customLoginBackground';
import createFutureErrorRecord from "@salesforce/apex/Utility.createFutureErrorRecord";
import { CurrentPageReference } from 'lightning/navigation';

import { ShowToastEvent } from 'lightning/platformShowToastEvent';

export default class CustomLoginFormLWC extends LightningElement {
    
    isUsernamePasswordEnabled;
    isForgotURL;
    @api username='';
    password = '';
    logoImg = logo;
    loginGradientImg = loginGradient;
    isValidCred = false;
    missingUsername = false;
    isCallForgot = false;
    @track loginBackground = customLoginBackground;
    forgotPasswordUrl;
    isHeadlessForgotPasswordEnabled=false;

    @wire(CurrentPageReference)
    getStateParameters(currentPageReference) {
        if (currentPageReference) {
            this.urlStateParameters = currentPageReference.state;
            this.username = this.urlStateParameters.username ?? this.username; //in case no username parameter is supplied
        }
    }    
   @wire(getLoginSettings)
   wiredGetLoginSettings({error,data}){
        if (data){
            this.isUsernamePasswordEnabled = data.usernamePasswordEnabled;
            this.forgotPasswordUrl = data.forgotPasswordUrl;
            this.isHeadlessForgotPasswordEnabled = data.headlessForgotPasswordEnabled;
        }else if (error) {
            // alert(error);
            console.log(error);            
        }
   }
    renderedCallback() {        
        getLoginSettings().then(result=>{
            if (result) {
                const data = result;
                this.isUsernamePasswordEnabled = data.usernamePasswordEnabled;
                this.forgotPasswordUrl = data.forgotPasswordUrl;
                this.isHeadlessForgotPasswordEnabled = data.headlessForgotPasswordEnabled;
            }            
        })
        .catch(error => {
            createFutureErrorRecord( {exceptionMessage: error.message ?? error.body.message, stackTrace: error.stack ?? error.body.stackTrace, lineNum: 0, errortype: 'Javascript', procname: 'CustomLoginFormLWC.connectedCallback'}) ;
            console.error('Exception thrown:  ', error, 'stack trace:  ', error.stack);            
            });         
    }
    handlePasswordChange(event) {
        event.preventDefault();
        event.stopPropagation();
        this.password = event.target.value;
    }
    handleUsernameChange(event) {
        event.preventDefault();
        event.stopPropagation();
        this.username = event.target.value;
    }
    handleClick(event){
        console.log('click login');
        if(this.username && this.password){
            event.preventDefault();
            this.isValidCred = false;
            login({ username: this.username, password: this.password })
                .then((result) => {
                //    if (this.isValidURL(result)) {
                       window.location.href = result.replace('System.PageReference[', '').replace(']', '').trim();;
                //    }
                //    else {
                //     //    alert(result);
                //        console.log(result);
                //    }
               })
                .catch((error) => {
                //    alert(error);
                   console.log(error);
                   
            });
        } else if (!this.username) {
            console.log('click else if login');
            this.isValidCred = true;
            // this.showToast('Error', 'Please Enter the UserName', 'error');
            this.showToast('Error', 'Please Enter the UserName', 'error');
            console.log('click else if login 82');
        } else {
            console.log('click else login');
            // this.showToast('Error', 'Please Enter the Password', 'error');
            this.isValidCred = true;
            this.showToast('Error', 'Please Enter the Password', 'error');
        }
    }
    isValidURL(url) {
        const urlPattern = /^(https?|ftp):\/\/[^\s/$.?#].[^\s]*$/;
        return urlPattern.test(url);
    }
    handleForgetPasswordCreate () {   
        if (this.isHeadlessForgotPasswordEnabled==true) { //for the headless forgot pasword api, just redirect to the forgot password page for it
            this.missingUsername  = false;
            window.location.href = this.forgotPasswordUrl+'?c__createOrReset=create';                             
        } else {
            if (this.username) {
                forgotPassword({ username: this.username, checkEmailUrl: this.forgotPasswordUrl }) //validates the username and sends an email to them 
                .then((result) => { //result is the same as this. forgotPasswordUrl
                    this.isCallForgot = true;       
                    window.location.href = this.forgotPasswordUrl + '?userName=' + this.username;                    
                })
            } else  {
               this.missingUsername  = true;
            }
        }
    }
    handleForgetPasswordReset () {   
        if (this.isHeadlessForgotPasswordEnabled==true) { //for the headless forgot pasword api, just redirect to the forgot password page for it
            this.missingUsername  = false;
            window.location.href = this.forgotPasswordUrl+'?c__createOrReset=reset';                             
        } else {
            if (this.username) {
                forgotPassword({ username: this.username, checkEmailUrl: this.forgotPasswordUrl }) //validates the username and sends an email to them 
                .then((result) => { //result is the same as this. forgotPasswordUrl
                    this.isCallForgot = true;       
                    window.location.href = this.forgotPasswordUrl + '?userName=' + this.username;                    
                })
            } else  {
               this.missingUsername  = true;
            }
        }
    }    
    // showToast(title, message, variant) {
    //     this.dispatchEvent(new ShowToastEvent({ title, message, variant }));
    // }
    showToast(title, message, variant) {
        const event = new ShowToastEvent({
            title: title,
            message: message,
            variant: variant,
        });
        this.dispatchEvent(event);
    }
}