import { LightningElement, api, wire } from 'lwc';
import updateAccount from '@salesforce/apex/VitalAccountController.updateAccount';
import getAccountDetails from '@salesforce/apex/VitalAccountController.getAccountDetails';
import uploadFile from '@salesforce/apex/FileUploadController.uploadFile';
import { ShowToastEvent } from 'lightning/platformShowToastEvent';

export default class LwCTest extends LightningElement {
    @api recordId ;
    account = {
        FirstName: '',
        MiddleName: '',
        LastName: ''
    };

    isEditMode = false;
    uploadedFileName = ''; // Name of the uploaded file
    uploadedFileUrl = '';  // URL to access the uploaded file
    file; // For the file upload

    allSections = ['personal', 'Military', 'education', 'currentFmaily', 'SocialMedia', 'AminFields'];

    @wire(getAccountDetails, { accountId: '$recordId' })
    wiredAccount({ error, data }) {
        if (data) {
            this.account = data;
            this.errors = null;
            console.log('Account Data ---- ', JSON.stringify(this.account));
        } else if (error) {
            this.errors = error;
            this.account = null;
        }
    }

    handleFilesChange(event) {
        if (event.target.files.length > 0) {
            this.uploadedFileName = event.target.files[0].name;
            this.file = event.target.files[0];
        }
    }

    handleUpload() {
        if (this.file) {
            const reader = new FileReader();
            reader.onload = () => {
                const base64 = reader.result.split(',')[1];
                this.uploadFile(base64);
            };
            reader.readAsDataURL(this.file);
        } else {
            this.showToast('Error', 'Please select a file to upload.', 'error');
        }
    }

    uploadFile(base64) {
        uploadFile({ fileName: this.uploadedFileName, base64Data: base64, parentId: this.recordId })
            .then(contentVersionId => {
                console.log('File uploaded successfully, ContentVersionId:', contentVersionId);
                this.showToast('Success', 'File uploaded successfully!', 'success');
                this.uploadedFileUrl = `/sfc/servlet.shepherd/version/download/${contentVersionId}`;
            })
            .catch(error => {
                console.error('File upload error:', JSON.stringify(error));
                this.showToast('Error', error.body ? error.body.message : 'File upload failed.', 'error');
            });
    }

    showToast(title, message, variant) {
        this.dispatchEvent(new ShowToastEvent({ title, message, variant }));
    }

    toggleEdit() {
        this.isEditMode = !this.isEditMode;
    }

    cancelEdit() {
        this.isEditMode = false;
    }

    handleInputChange(event) {
        const field = event.target.dataset.field;
        const value = event.target.value;
        this.account = { ...this.account, [field]: value };
        console.log('Form Data --: ', this.account[field]);
        console.log('Object Form  --: ', JSON.stringify(this.account));
    }

    saveRecord() {
        updateAccount({ acc: this.account })
            .then(result => {
                this.account = result;
                this.toggleEdit();
                this.showToast('Success', 'Account updated successfully', 'success');
                console.log('Record Submitted successfully');
            })
            .catch(error => {
                console.error('Account update error:', JSON.stringify(error));
                this.showToast('Error', error.body ? error.body.message : 'Account update failed!', 'error');
            });
    }
}