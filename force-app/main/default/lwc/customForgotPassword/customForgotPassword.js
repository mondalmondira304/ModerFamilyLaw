import { LightningElement, api, track, wire } from 'lwc';
import logo from '@salesforce/resourceUrl/Logo';
import loginGradient from '@salesforce/resourceUrl/loginFormGradient';
import { CurrentPageReference } from 'lightning/navigation';
import logPassReset from '@salesforce/apex/customForgotPasswordController.logPassReset';
const DEBUG = true;

export default class CustomForgotPassword extends LightningElement {
    logoImg = logo;
    loginGradientImg = loginGradient;
    @track isInit;
    @track passwordChangeSuccess;
    @track hasOTP;
    @track enteredOTP;
    @track username;
    @track recaptchaToken;
    @track otpCode;
    @track newPassword;
    @track confirmNewPassword;
    @track showSpinner;
    @track otpResponseHandler;
    @track otpResponseErrorHandler;
    @track passwordChangeResponseErrorHandler;
    @track passwordChangeResponseHandler;
    @track grecaptchaVerifiedHandler;
    @track grecaptchaInitializedHandler;
    @track recaptchaDivElement;
    @api recaptchaSiteKey; 
    @api actionName;
    @api siteUrl;
    pageTitle;
    loginUrl;
    createOrReset;
    otpError;

    connectedCallback() {
        this.loginUrl=this.siteUrl;  //after the new password is set, this.siteUrl is reset or goes out of scope        
        this.showSpinner = true;
        this.grecaptchaVerifiedHandler = this.handleGrecaptchaVerified.bind(this);
        document.addEventListener("grecaptchaVerified", this.grecaptchaVerifiedHandler);

        this.grecaptchaInitializedHandler = this.handleGrecaptchaInitialized.bind(this);
        document.addEventListener("grecaptchaInitialized", this.grecaptchaInitializedHandler);

        //Step 1: Dispatch event to initialize reCAPTCHA library with site key
        document.dispatchEvent(new CustomEvent("grecaptchaInit", {"detail": {"action": this.actionName,"recaptchaSiteKey":this.recaptchaSiteKey}}));
        this.pageTitle = (this.createOrReset=='create') ? 'Create Your Password':'Reset Your Password'
    }

    @wire(CurrentPageReference)
    getPageReferenceParameters(currentPageReference) {
        if (currentPageReference) {
            // Access the parameter from the URL
            this.createOrReset = currentPageReference.state.c__createOrReset;
        }
    }    
    //Step 1.1: confirmation of reCAPTCHA library initialization completion
    handleGrecaptchaInitialized(e) {
        if(e.detail.action === this.actionName)
        {   
            this.isInit = true;
            this.showSpinner = undefined;
        }
    }
    //Step 2: When reset button is clicked and username entered, dispatch event to get reCAPTCHA token for One-Time password
    handleRequestOTP(e) {
        let inputCmp = this.template.querySelector('.username');
        inputCmp.setCustomValidity('');
        inputCmp.reportValidity();
        if(this.username !== undefined && this.username !== null && this.username.trim() !== '')
        {
            this.showSpinner = true;
            document.dispatchEvent(new CustomEvent("grecaptchaExecute", {"detail": {"action":this.actionName+'_otp',"recaptchaSiteKey":this.recaptchaSiteKey}}));
        }
        else 
        {
            inputCmp.setCustomValidity('Please enter your registered email.');
            inputCmp.reportValidity();
        }
    }
    handleRequestOTPResponse(response, username, forgotPasswordProcessStep) 
    {
        this.consoleLog(JSON.stringify(response), 'response from request ' + forgotPasswordProcessStep + ': ');
        if(response !== undefined && response !== null && response.status !== undefined && response.status !== null && response.status === 'success')
        {
            this.hasOTP = true;
        }
    }
    handleRequestOTPResponseError(response, username, forgotPasswordProcessStep) 
    {
        this.consoleLog(JSON.stringify(response), 'error from request ' + forgotPasswordProcessStep + ': ');
        let inputCmp = this.template.querySelector('.username');
        inputCmp.setCustomValidity('');
        inputCmp.reportValidity();
        if(response.invalid_request !== undefined && response.invalid_request !== null)
        {
            inputCmp.setCustomValidity(response.invalid_request);
            inputCmp.reportValidity();
        }
    }
    handlePasswordChangeResponse(response, username, forgotPasswordProcessStep)
    { 
        let loginUrl=this.siteUrl;
        this.consoleLog(JSON.stringify(response), 'response from request ' + forgotPasswordProcessStep + ': ');
        if(response.status !== undefined && response.status !== null && response.status.trim() === 'success') {
            this.passwordChangeSuccess = true;
        }
        setTimeout(function() { window.location.replace(loginUrl);  }, 5000);        
    }
    handlePasswordChangeResponseError(response, username, forgotPasswordProcessStep)
    { 
        //err from request updatePassword: {"status_code":"invalid_otp","otp_error":"invalid OTP","status":"failed"}        
        this.consoleLog(JSON.stringify(response), 'err from request ' + forgotPasswordProcessStep + ': ');
        let passwordfield = this.template.querySelector('.confirmNewPassword');
        passwordfield.setCustomValidity('');
        passwordfield.reportValidity();
        let otpfield = this.template.querySelector('.otp');
        otpfield.setCustomValidity('');
        otpfield.reportValidity();
        if(response.status_code !== undefined && response.status_code !== null)
        {
            if(response.status_code === 'password_policy_check_failure')
            {
                passwordfield.setCustomValidity('You cannot reuse any of your past three passwords.  Please enter a new password.');                
                passwordfield.reportValidity();
            }
            if(response.status_code === 'invalid_otp') {
                otpfield.setCustomValidity('Your one-time code is invalid.  Enter the correct one-time code or request a new one-time code by using the button below.');
                otpfield.reportValidity();            
                this.otpError=true;
                this.otpCode=undefined;
            }
        }
    }
    handleResendCode(e) {  //reset some flags
        this.hasOTP = undefined;
        this.enteredOTP = undefined;
        this.otpError=undefined;
    }
    handleReenterCode(e) {
        this.hasOTP = true;
        this.enteredOTP = undefined;
    }
    //Step 3: upon one time password entry and new password validation, dispatch event to get reCAPTCHA token for password update
    handleUpdatePassword(e)
    {
        let passwordfield = this.template.querySelector('.otp');
        passwordfield.setCustomValidity('');
        passwordfield.reportValidity();  //clear any previous error messages
        if( this.sixCharacterOTP)   {
            this.enteredOTP = true;
        }  else {
            passwordfield.setCustomValidity('The one-time code must be 6 characters long.  Enter the correct one-time code or request a new one-time code by using the button below.');
            passwordfield.reportValidity();
            this.otpError=true;
        }        
        if( this.sixCharacterOTP &&
            this.confirmNewPassword !== undefined && this.confirmNewPassword !== null && this.confirmNewPassword.trim() !== '' && 
            this.newPassword !== undefined && this.newPassword !== null && this.newPassword.trim() !== '' && this.confirmNewPassword === this.newPassword)  
        {
                this.showSpinner = true;
                document.dispatchEvent(new CustomEvent("grecaptchaExecute", {"detail": {"action":this.actionName+'_updatePassword',"recaptchaSiteKey":this.recaptchaSiteKey}}));
        }
    }
    forgotPasswordRequest(username, password, otp, recapchaToken, forgotPasswordProcessStep, callbackFunction, errorCallbackFunction) {
        let expDomain = this.siteUrl;
        let forgotPasswordURI = '/services/auth/headless/forgot_password';
        let client = new XMLHttpRequest();
        client.open("POST", expDomain + forgotPasswordURI, true);
        client.setRequestHeader("Content-Type", "application/json");  
        let requestBody = {
            username: username,
            newpassword: password,
            otp: otp,
            recaptcha: recapchaToken
        }
        client.send(JSON.stringify(requestBody)); 
        var thisComponent = this;
        client.onreadystatechange = function() {
            try {
                if(client.readyState == 4) {
                    thisComponent.consoleLog(client.response, 'Client Response after ready state 4: ');
                    if (client.status == 200) {
                        callbackFunction(JSON.parse(client.response), username, forgotPasswordProcessStep);
                        thisComponent.handleCreateEmailLog(username);
                    } else {
                        errorCallbackFunction(JSON.parse(client.response), username, forgotPasswordProcessStep);
                    }
                    thisComponent.showSpinner = undefined;
                } 
            } catch(err){
                thisComponent.consoleLog(err+'', 'readystatechange function error: ');
            }
        }
    }
    handleCreateEmailLog(emailAddress) {
        logPassReset({ emailAddress: emailAddress })
            .then((data) => {
                console.log(data);
            })
    }
    handleUsernameChange(e) {
        this.username = e.target.value.trim();
    }
    handleotpCodeChange(e) {
        this.otpError=undefined;
        this.otpCode = e.target.value.trim();
        let passwordfield = this.template.querySelector('.otp');
        passwordfield.setCustomValidity('');
        passwordfield.reportValidity();
        if(this.otpCode === undefined || this.otpCode === null || this.otpCode.trim() === '')
        {
            passwordfield.setCustomValidity('Please enter the One Time Password.');
            passwordfield.reportValidity();
        }
    }
    /*
    handleNext(e) {
        let passwordfield = this.template.querySelector('.otp');
        passwordfield.setCustomValidity('');
        passwordfield.reportValidity();
        if( this.sixCharacterOTP)   {
            this.enteredOTP = true;
        }
        else {
            passwordfield.setCustomValidity('Please enter the one-time code.  The one-time code must be 6 characters long.');
            passwordfield.reportValidity();
        }
    }*/
    handleAlreadyHaveCode(e) {
        let inputCmp = this.template.querySelector('.username');
        inputCmp.setCustomValidity('');
        inputCmp.reportValidity();

        if(this.username !== undefined && this.username !== null && this.username.trim() !== '')
        {
            this.hasOTP = true;
        }
        else 
        {
            inputCmp.setCustomValidity('Please enter your registered email.');
            inputCmp.reportValidity();
        }
    }  
    @track values = [];
    get options() {
        return [
            { label: '8 Characters', value: '8characters' },
            { label: '1 Upper Case Letter', value: '1letter' },
            { label: '1 Number', value: '1number' }, 
            { label: 'Passwords Match', value: 'passwordmatch' },            
        ];
    }
    get showUpdateButton(){
        return (this.values.length===4 && this.otpError===undefined);  //if the password meets the four requirements.
    }
    get sixCharacterOTP (){
        if (this.otpCode==undefined || this.otpCode==null || this.otpCode=='') {
            return false;
        }
        return (this.otpCode.length===6);
    }
    handleNewPasswordChange(e) {
        this.newPassword = e.target.value.trim();
        let inputCmp = this.template.querySelector('.confirmNewPassword');
        inputCmp.setCustomValidity('');
        inputCmp.reportValidity();
        if (this.newPassword !== undefined && this.newPassword !== null && this.newPassword.trim() !== '')
        {
              if (this.newPassword.length >= 8) {
                if (this.values.indexOf("8characters")==-1){
                    this.values.push("8characters");
                }                                                          
              } else {            
                let index = this.values.indexOf("8characters"); 
                if (index>=0){               
                    this.values.splice(index, 1);
                }
              }
              if (/[A-Z]/.test(this.newPassword)) { 
                if (this.values.indexOf("1letter")==-1){
                    this.values.push("1letter");
                }                                                  
              } else {                
                let index = this.values.indexOf("1letter");
                if (index>=0){
                    this.values.splice(index, 1);
                }                
              } 
              if (/[0-9]/.test(this.newPassword)) {
                if (this.values.indexOf("1number")==-1){
                    this.values.push("1number");
                }                                     
              } else {              
                let index = this.values.indexOf("1number");
                if (index>=0){
                    this.values.splice(index, 1);
                }                   
              } 
              this.handleConfirmNewPasswordChange();  //TODO not working a e.target.value is the first password field
              /*if (this.confirmNewPassword !== this.newPassword) {
                inputCmp.setCustomValidity('Passwords do not match.');
              }*/            
            //inputCmp.reportValidity();
        } else { //reset
            this.values=[];
        }
    }
    handleConfirmNewPasswordChange(e) {
        if (e!=null){
            this.confirmNewPassword = e.target.value.trim();  //else the this.confirmNewPassword value has not changed but this.newPassword has
        }
        let inputCmp = this.template.querySelector('.confirmNewPassword');
        inputCmp.setCustomValidity('');
        inputCmp.reportValidity();
        if (this.confirmNewPassword == undefined || this.confirmNewPassword == null || this.confirmNewPassword?.trim() == '' ||  //to handle the initial, negative condtions
            this.newPassword == undefined || this.newPassword == null || this.newPassword?.trim() == '' || this.confirmNewPassword !== this.newPassword)
        {
            let index = this.values.indexOf("passwordmatch");
                if (index>=0){
                    this.values.splice(index, 1);
            }             
        }
        if(this.confirmNewPassword !== undefined && this.confirmNewPassword !== null && this.confirmNewPassword.trim() !== '' &&  //to handle the positive conditions
            this.newPassword !== undefined && this.newPassword !== null && this.newPassword.trim() !== '' && this.confirmNewPassword === this.newPassword)
        {
            if (this.values.indexOf("passwordmatch")==-1){
                    this.values.push("passwordmatch");
            }   

        } else {
            let index = this.values.indexOf("passwordmatch");
                if (index>=0){
                    this.values.splice(index, 1);
            }            
        }
    }

    //Step 2.1, 3.1: Event listener for reCAPTCHA token generation to process next step of OTP or password update request
    handleGrecaptchaVerified(e)
    {
        if(e.detail.action.indexOf(this.actionName) > -1 && e.detail.recaptchaSiteKey === this.recaptchaSiteKey && e.detail.response !== undefined && e.detail.response !== null)
        {           
            this.recaptchaToken = e.detail.response;
            this.consoleLog(this.recaptchaToken, 'token: ');
            document.dispatchEvent(new Event("grecaptchaReset"));
            if(e.detail.action === (this.actionName + '_otp'))
            {
                this.otpResponseHandler = this.handleRequestOTPResponse.bind(this);
                this.otpResponseErrorHandler = this.handleRequestOTPResponseError.bind(this);
                this.forgotPasswordRequest(this.username, null, null, this.recaptchaToken, 'requestOTP', this.otpResponseHandler, this.otpResponseErrorHandler);
            } 
            else if(e.detail.action === (this.actionName + '_updatePassword'))
            {
                this.username = (this.username !== undefined && this.username !== null && this.username.trim() !== '') ? this.username : null;
                this.passwordChangeResponseHandler = this.handlePasswordChangeResponse.bind(this);
                this.passwordChangeResponseErrorHandler = this.handlePasswordChangeResponseError.bind(this);
                this.forgotPasswordRequest(this.username, this.confirmNewPassword, this.otpCode, this.recaptchaToken, 'updatePassword', this.passwordChangeResponseHandler, this.passwordChangeResponseErrorHandler);
            }
            else 
            {
                this.showSpinner = undefined;
            }
        }
        console.log(this.passwordChangeResponseErrorHandler);
    }
    consoleLog(text = '', before = '', after = '')
    {
        if(DEBUG === true)
        {
            console.log(before + text + after);
        }
    }
}