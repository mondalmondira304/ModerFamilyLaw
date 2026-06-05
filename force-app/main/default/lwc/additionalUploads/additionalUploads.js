import { LightningElement, api, track } from 'lwc';
import getAssociatedFiles from '@salesforce/apex/FileUploadController.getAssociatedFiles';
import deleteFileAndDocument from '@salesforce/apex/FileUploadController.deleteFileAndDocument';

export default class SpecialUpload extends LightningElement {
    @api recordId;  //this would be the matter id
    @track listOfUploadedFileNames = [];
    @track error;    
    //columns=[{ label: 'Previously Uploaded File(s)', fieldName: 'name' },];

    get acceptedFormats() {
        return ['.pdf', '.png', '.jpg', '.jpeg', '.csv', '.docx', '.xlsx', '.xlsm', '.xls'];
    }
    connectedCallback() {
        this.getFiles();        
    }
    handleUploadFinished(event){ // to refresh the file list
        this.getFiles();
    }
    async getFiles()    {
        try {
            let files =  await getAssociatedFiles ( { recordId: this.recordId });
            this.error = undefined;
            this.listOfUploadedFileNames = files ? files.map((aFile) => {
                return {    name: aFile.Title,  id: aFile.Id    }
            }) : [];                              
        } catch (e){
            this.error = e;
            this.uploadedTaxReturnFile = [];
            this.uploadedCurrentEmploymentFile = [];
            createFutureErrorRecord( {exceptionMessage: e.message ?? e.body.message, stackTrace: e.stack ?? e.body.stackTrace, lineNum: 0, errortype: 'Javascript', procname: 'assetSubPage.getFiles'}) ;                    
        }
    }
    handleFileDelete(event) {
        const index = event.detail.name;
        const fileId = this.listOfUploadedFileNames[index]?.id;
        if (fileId) {
            deleteFileAndDocument({ contentVersionId: fileId })
                .then(() => {
                    this.getFiles(); //* to refresh the file list                   
                })
                .catch(() => {
                    this.showToast('Error', 'Failed to delete file.', 'error');
                });
        } else {
            this.showToast('Success', 'File removed successfully!', 'success');
        }
    }
}