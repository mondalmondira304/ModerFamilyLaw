/**
 * @description Third-party application form component for SimpleStart Flow
 * Creates a new third-party Account record and navigates to next Flow screen
 * @author Simple Start Development Team
 * @version 2.0 - Guest User Compatible
 */
import { LightningElement, api, track, wire } from 'lwc';
import { FlowNavigationNextEvent } from 'lightning/flowSupport';
import { ShowToastEvent } from 'lightning/platformShowToastEvent';
import { getPicklistValues } from 'lightning/uiObjectInfoApi';
import STATE_FIELD from '@salesforce/schema/Account.State_A__c';
import createThirdPartyAccountSimple from '@salesforce/apex/CustomThirdPartyController.createThirdPartyAccountSimple';
import getParentAccountId18 from '@salesforce/apex/CustomThirdPartyController.getParentAccountId18';
import MFL_TopFullLogo from '@salesforce/resourceUrl/MFL_TopFullBlack';

export default class SsThirdPartyApplicationForm extends LightningElement {
    // === recordId handling ===
    _recordId;
    @api
    get recordId() { return this._recordId; }
    set recordId(val) {
        this._recordId = val;
        // set a non-null default immediately so Flow outputs are populated
        if (val) {
            this.parentAccountId = this.parentAccountId || val;
            // normalize 15 -> 18 asynchronously
            this.normalizeParentId(val);
        }
    }

    // Input properties from Flow
    @api recordTypeId;   // Third-Party Account RecordType Id

    // Output properties back to Flow
    @api thirdPartyId;    // New Third-Party Account Id (Flow output)
    @api parentAccountId; // 18-char Parent Account Id (normalized)

    // Private reactive properties
    @track errorMessage = '';
    @track isLoading = false;
    @track stateOptions = [];

    @wire(getPicklistValues, { recordTypeId: '$recordTypeId', fieldApiName: STATE_FIELD })
    wiredStatePicklistValues({ error, data }) {
        if (data) {
            this.stateOptions = data.values;
            console.log('State picklist values loaded:', JSON.stringify(this.stateOptions));
        } else if (error) {
            console.error('Error loading state picklist values', error);
        }
    }

    // Form data object
    @track formData = {
        firstName: '',
        middleName: '',
        lastName: '',
        birthdate: '',
        socialSecurityNumber: '',
        mobilePhone: '',
        email: '',
        street: '',
        city: '',
        state: '',
        postalCode: '',
        annualIncome: ''
    };

    // Static resource URL for logo
    get topLogoUrl() {
        return MFL_TopFullLogo;
    }

    /**
     * @description Component initialization
     */
    connectedCallback() {
        // If Flow didn't pass recordId, try URL param (setter will normalize)
        if (!this._recordId) {
            const fromUrl = this.getUrlParameter('recordId');
            if (fromUrl) {
                this.recordId = fromUrl; // triggers setter above
            }
        }

        console.log('=== COMPONENT INITIALIZED ===');
        console.log('- recordId (raw/backing):', this._recordId);
        console.log('- recordTypeId:', this.recordTypeId);
        console.log('==============================');
    }

    /**
     * @description Normalize recordId to 18-char and set parentAccountId
     */
    async normalizeParentId(idFromContext) {
        try {
            if (!idFromContext) {
                this.parentAccountId = null;
                return;
            }
            const normalized = await getParentAccountId18({ recordId: idFromContext });
            const safe = normalized || idFromContext;
            this.parentAccountId = safe;
            this._recordId = safe; // keep aligned without re-triggering setter
            console.log('Parent Account Id (18):', this.parentAccountId);
        } catch (e) {
            console.error('Failed to normalize parent Id, using original:', e);
            this.parentAccountId = idFromContext;
        }
    }

    /**
     * @description Gets URL parameter value
     * @param {String} param Parameter name
     * @return {String} Parameter value
     */
    getUrlParameter(param) {
        const urlParams = new URLSearchParams(window.location.search);
        const value = urlParams.get(param);
        console.log(`URL parameter ${param}:`, value);
        return value;
    }

    // =============================
    // Validation helpers 
    // =============================
    digitsOnly(value) {
        return (value || '').toString().replace(/\D/g, '');
    }

    setInputValidity(inputEl, message) {
        inputEl.setCustomValidity(message || '');
        inputEl.reportValidity();
    }

    enforcePhone(inputEl) {
        let digits = this.digitsOnly(inputEl.value);
        digits = digits.substring(0, 10); 
        inputEl.value = digits;
        this.formData = { ...this.formData, mobilePhone: digits };

        if (!digits) {
            this.setInputValidity(inputEl, 'Mobile phone is required.');
        } else if (digits.length !== 10) {
            this.setInputValidity(inputEl, 'Enter a 10-digit mobile phone number (numbers only).');
        } else {
            this.setInputValidity(inputEl, '');
        }
    }

    enforceSSN(inputEl) {
        let digits = this.digitsOnly(inputEl.value);
        digits = digits.substring(0, 9); 
        inputEl.value = digits;
        this.formData = { ...this.formData, socialSecurityNumber: digits };

        if (!digits) {
            this.setInputValidity(inputEl, 'Social Security Number is required.');
        } else if (digits.length !== 9) {
            this.setInputValidity(inputEl, 'Enter a 9-digit SSN (numbers only).');
        } else {
            this.setInputValidity(inputEl, '');
        }
    }

    /**
     * @description Handles input changes and updates form data
     * Enforces deterministic formatting for:
     * - mobilePhone: 10 digits only
     * - socialSecurityNumber: 9 digits only
     * @param {Event} event Input change event
     */
    handleInputChange(event) {
        const fieldName = event.target.name;

        // Deterministic enforcement for these two fields
        if (fieldName === 'mobilePhone') {
            this.enforcePhone(event.target);
            return;
        }
        if (fieldName === 'socialSecurityNumber') {
            this.enforceSSN(event.target);
            return;
        }

        // Default behavior (no change to your existing fields)
        const fieldValue = event.target.value;
        this.formData = { ...this.formData, [fieldName]: fieldValue };

        // If user corrects a field, clear any custom error on that input
        if (event?.target?.setCustomValidity) {
            event.target.setCustomValidity('');
            
        }
    }

    /**
     * @description Handles form submission with validation and field injection
     * @param {Event} event Form submit event
     */
    handleSubmit(event) {
        event.preventDefault();
        console.log('Form submission started');

        if (this.isLoading) {
            console.log('Form already loading, skipping submission');
            return;
        }

        if (!this.validateInputs()) {
            console.log('Form validation failed');
            return;
        }

        console.log('Form validation passed, creating account...');
        this.setLoadingState(true);
        this.clearErrors();

        // Create account data object
        const accountData = {
            FirstName: this.formData.firstName,
            MiddleName: this.formData.middleName,
            LastName: this.formData.lastName,
            Birthdate__c: this.formData.birthdate,
            Social_Security_Number__c: this.formData.socialSecurityNumber,
            PersonMobilePhone: this.formData.mobilePhone,
            PersonEmail: this.formData.email,
            PersonMailingStreet: this.formData.street,
            PersonMailingCity: this.formData.city,
            State_A__c: this.formData.state,
            PersonMailingPostalCode: this.formData.postalCode,
            Annual_household_income__c: this.formData.annualIncome,
            // Only include RecordTypeId - no parent relationship
            RecordTypeId: this.recordTypeId || 'NO_RECORD_TYPE_PROVIDED',
            Type: 'Third Party'
        };

        console.log('=== ACCOUNT DATA DEBUG ===');
        console.log('RecordTypeId being sent:', accountData.RecordTypeId);
        console.log('Full accountData:', JSON.stringify(accountData, null, 2));
        console.log('==========================');

        // Call Apex method to create the account
        this.createAccount(accountData);
    }

    /**
     * @description Creates the third-party account via Apex
     * @param {Object} accountData Account data to create
     */
    async createAccount(accountData) {
        try {
            console.log('Creating account with data:', accountData);
            const result = await createThirdPartyAccountSimple({ accountData: accountData });
            console.log('Account created successfully with ID:', result);
            this.thirdPartyId = result; // result is the ID string directly
            // ensure Flow gets the normalized parent Id
            this.parentAccountId = this.parentAccountId || this.recordId;
            console.log('thirdPartyId set to:', this.thirdPartyId);
            console.log('parentAccountId set to:', this.parentAccountId);
            console.log('Third-party account created successfully!');
            this.handleSuccess(result);
        } catch (error) {
            console.error('Error creating account:', error);
            this.handleError(error);
        }
    }

    /**
     * @description Validates required inputs before submission
     * Uses lightning-input built-in validation + hard checks for phone/ssn length
     * @return {Boolean} True if validation passes
     */
    validateInputs() {
        // Validate all inputs/comboboxes that support reportValidity
        const inputs = Array.from(this.template.querySelectorAll('lightning-input, lightning-combobox'));
        let allValid = true;

        inputs.forEach((el) => {
            // Force deterministic re-check for phone/ssn right before submit
            if (el.name === 'mobilePhone') {
                this.enforcePhone(el);
            } else if (el.name === 'socialSecurityNumber') {
                this.enforceSSN(el);
            }

            // Built-in validation (required/pattern/email/etc.)
            if (typeof el.reportValidity === 'function') {
                const ok = el.reportValidity();
                if (!ok) allValid = false;
            }
        });

        // Extra hard guards (in case something bypassed UI)
        const phoneDigits = this.digitsOnly(this.formData.mobilePhone);
        const ssnDigits = this.digitsOnly(this.formData.socialSecurityNumber);

        if (phoneDigits.length !== 10) allValid = false;
        if (ssnDigits.length !== 9) allValid = false;

        if (!allValid) {
            this.setError('Please fix the highlighted fields before submitting.');
        }

        return allValid;
    }

    /**
     * @description Handles successful account creation
     * @param {Object} result Success result with new record details
     */
    handleSuccess(result) {
        this.setLoadingState(false);
        this.clearErrors();

        try {
            // Navigate to next Flow screen
            this.navigateNext();
        } catch (error) {
            this.handleFormError('Error processing successful submission: ' + error.message);
        }
    }

    /**
     * @description Handles form errors
     * @param {Error} error Error from account creation
     */
    handleError(error) {
        this.setLoadingState(false);

        let errorMsg = 'An error occurred while saving the form.';
        if (error?.body?.message) {
            errorMsg = error.body.message;
        } else if (error?.message) {
            errorMsg = error.message;
        }

        this.setError(errorMsg);
        this.showErrorToast(errorMsg);
    }

    /**
     * @description Generic error handler for internal errors
     * @param {String} message Error message
     */
    handleFormError(message) {
        this.setLoadingState(false);
        this.setError(message);
        this.showErrorToast(message);
    }

    /**
     * @description Sets loading state and manages UI
     * @param {Boolean} loading Loading state
     */
    setLoadingState(loading) {
        this.isLoading = loading;
    }

    /**
     * @description Sets error message
     * @param {String} message Error message
     */
    setError(message) {
        this.errorMessage = message;
    }

    /**
     * @description Clears error messages
     */
    clearErrors() {
        this.errorMessage = '';
    }

    /**
     * @description Navigates to next step in Flow
     */
    navigateNext() {
        const navigateNextEvent = new FlowNavigationNextEvent();
        this.dispatchEvent(navigateNextEvent);
    }

    /**
     * @description Shows error toast message
     * @param {String} message Error message
     */
    showErrorToast(message) {
        const event = new ShowToastEvent({
            title: 'Error',
            message: message,
            variant: 'error'
        });
        this.dispatchEvent(event);
    }

    /**
     * @description Checks if all required fields are filled (controls Submit visibility)
     * Also enforces phone(10) + ssn(9) digit lengths so button disables until valid.
     */
    get isFormValid() {
        const requiredFields = [
            'firstName',
            'lastName',
            'birthdate',
            'socialSecurityNumber',
            'mobilePhone',
            'email',
            'street',
            'city',
            'state',
            'postalCode',
            'annualIncome'
        ];

        const hasAllRequired = requiredFields.every(field => {
            const value = this.formData[field];
            return value !== null && value !== undefined && value.toString().trim() !== '';
        });

        if (!hasAllRequired) return false;

        // Deterministic length checks
        const phoneDigits = this.digitsOnly(this.formData.mobilePhone);
        const ssnDigits = this.digitsOnly(this.formData.socialSecurityNumber);

        return phoneDigits.length === 10 && ssnDigits.length === 9;
    }

    get isSubmitDisabled() {
        return !this.isFormValid;
    }
}