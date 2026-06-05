import { LightningElement, api, wire } from 'lwc';
import forgotPassword from '@salesforce/apex/LightningForgotPasswordController.forgotPassword';
import getForgotPasswordUrl from '@salesforce/apex/LightningLoginFormController.getForgotPasswordUrl';

import logo from '@salesforce/resourceUrl/Logo';
import loginGradient from '@salesforce/resourceUrl/loginFormGradient';

export default class ForgotPasswordLWC extends LightningElement {

    @api user;
    logoImg = logo;
    loginGradientImg = loginGradient;
    username;
    
    @wire(getForgotPasswordUrl)
    wiredIsgetForgotPasswordUrl({ error, data }) {
        if (data) {
            this.isForgotURL = data;
            console.log('Forgot URL::',this.isForgotURL);
        } else if (error) {
            // alert(error);
            console.log(error);
            
        }
    }

    connectedCallback () {
        const url = window.location.href;
        const params = new URL(url).searchParams;
        this.username = params.get("userName");
        // console.log(userName)
        
    }

    // handleUsernameChange(event) {
    //     event.preventDefault();
    //     this.username = event.target.value;
    // }

    handleForgetPassword () {
        console.log('getting userName',this.username);
        if (this.username) {
            console.log('getting userName 1',this.username);
            this.isForgot  = 'true';
            forgotPassword({ username: this.username, checkEmailUrl:this.isForgotURL })
            .then((result) => {
                console.log('result :: ',result);
                let temp = result.replace(/(login\/).*/, '$1CheckPasswordResetEmail');
                console.log('getting userName 1',temp);
                window.location.href = temp;
                // CheckPasswordResetEmail
                
            })
        } else {
            this.isForgot  = true;
        }
    }
}