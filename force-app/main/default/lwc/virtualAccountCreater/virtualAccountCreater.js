import { LightningElement, wire, track } from 'lwc';
import logo from '@salesforce/resourceUrl/Logo';
import uploadBlock from '@salesforce/resourceUrl/UploadBlock';
import matterBackground from '@salesforce/resourceUrl/matterBackground';
import editIcon from '@salesforce/resourceUrl/editIcon';
import getMatterDetailsForPortalUser from "@salesforce/apex/MatterController.getMatterDetailsForPortalUser";
import getAllMatterDetailsForPortalUser from "@salesforce/apex/MatterController.getAllMatterDetailsForPortalUser";
import getMatterDetailsForSelectedPortalUser from "@salesforce/apex/MatterController.getMatterDetailsForSelectedPortalUser";
import getCurrentUserDetail from "@salesforce/apex/MatterController.getCurrentUserDetail";
import updateMatterDateTime from '@salesforce/apex/VitalAccountController.updateMatterDateTime';
import getPortalVideos from '@salesforce/apex/VitalAccountController.getPortalVideos';
import getCIFormStatus from "@salesforce/apex/TaskController.getCIFormStatus";
import editCIFormStatus from "@salesforce/apex/TaskController.editCIFormStatus";
import getIndividualCIFormStatus from "@salesforce/apex/TaskController.getIndividualCIFormStatus";
import getChildrenList from '@salesforce/apex/ChildrenController.getChildrenList';
import createFutureErrorRecord from "@salesforce/apex/Utility.createFutureErrorRecord";
import loginGradient from '@salesforce/resourceUrl/modalPopupGradient';
import { ShowToastEvent } from 'lightning/platformShowToastEvent';
import { NavigationMixin } from 'lightning/navigation';
import { loadStyle } from 'lightning/platformResourceLoader';
import customCSS from '@salesforce/resourceUrl/toastCSS';
import createThread from '@salesforce/apex/OpenAIAssistantService.createThread';
import sendMessageAndRun from '@salesforce/apex/OpenAIAssistantService.sendMessageAndRun';
import pollRunStatus from '@salesforce/apex/OpenAIAssistantService.pollRunStatus';
import getAssistantMessages from '@salesforce/apex/OpenAIAssistantService.getAssistantMessages';
import MobileChatModal from 'c/mobileChatModal';
import { subscribe, unsubscribe, onError, setDebugFlag, isEmpEnabled } from 'lightning/empApi';
const MATTERCREATEDEVENT = '/event/Matter_Created__e';
const desiredOrder = [
  "Vitals",
  "Contact",
  "Identity",
  "Marriage",
  "Education",
  "Military",
  "Current Family",
  "Social Media",
  "Opposing Party",
  "OP-Contact",
  "OP-Identity",
  "OP-Family",
  "OP-Education",
  "OP-Military",
  "OP-Social Media",
  "OP-Service of Process",
  "Children",
  "Children With OP",
  "Children from a Different Relationship",
  "Assets",
  "Vehicles",
  "Real Property",
  "Bank Accounts",
  "Investment Accounts",
  "Retirement Accounts",
  "Life Insurance",
  "Furniture/Personal Property",
  "Additional",
  "Debts",
  "Credit Cards",
  "Additional Debts",
  "Income",
  "Current Employment",
  "Current Self Employment",
  "Previous Employment",
  "Income from Benefits",
  "Support Income",
  "Investment Income",
  "Income from Trusts",
  "Rental Income",
  "Other Income",
  "Tax Returns",
  "Expenses",
  "Housing Expenses",
  "Utilities",
  "Food and Supplies",
  "Health Care Costs",
  "Vehicles/Transportation",
  "Monthly Payroll Expenses",
  "Children Expenses/Activities",
  "Your Education Expenses",
  "Maintenance/Child Support",
  "Entertainment",
  "Legal Expenses",
  "Miscellaneous",
  "Additional Uploads"
];
export default class VirtualAccountCreater extends NavigationMixin(LightningElement) {
  @track manageNextBtn = true;
  @track isCSSLoaded = false;
  @track parent1Data = {};
  @track parent2Data = {};
  @track allMatterCases = [];
  @track attorney;
  @track OPvalidateList=[];
  @track VITALvalidateList=[];
  @track matterData = {
        Date_of_Marriage__c: '',
        Marriage_City__c: '',
        Marriage_State__c: '',
        Marriage_Country__c: '',
        Date_of_Separation__c: '',
        Name_Change__c: '',
        New_Restored_Name__c: '',
        Phone: '',
        PersonMobilePhone: '',
        Matter_ID_Full__c: ''
  };
  @track steps = [
    {index: 1, name: 'Vitals', hasConnector: true, iconName: 'utility:minimize_window', isIcon: false, sectionCSS: 'expand-icon', subSteps: [],},
    {index: 2, name: 'Opposing Party',hasConnector: true, iconName: 'utility:add', isIcon: true, sectionCSS: 'collapse-section', subSteps: [],},
    {index: 3, name: 'Children', hasConnector: true, iconName: 'utility:add', isIcon: true, sectionCSS: 'collapse-section', subSteps: [],},
    {index: 4, name: 'Assets', hasConnector: true, iconName: 'utility:add', isIcon: true, sectionCSS: 'collapse-section', subSteps: [],},
    {index: 5, name: 'Debts', hasConnector: true, iconName: 'utility:add', isIcon: true, sectionCSS: 'collapse-section', subSteps: [],},
    {index: 6, name: 'Income', hasConnector: true, iconName: 'utility:add', isIcon: true, sectionCSS: 'collapse-section', subSteps: [],},
    {index: 7, name: 'Expenses', hasConnector: true, iconName: 'utility:add', isIcon: true, sectionCSS: 'collapse-section', subSteps: [],},
    {index: 8, name: 'Additional Uploads', hasConnector: true, iconName: 'utility:add', isIcon: true, sectionCSS: 'collapse-section', subSteps: [],},    
  ];
  @track vitalSubTab = [{Status: 'Open', ParentTab: 'Vitals', subIndex: 1, name: 'Contact' },{Status: 'Open', ParentTab: 'Vitals', subIndex: 2, name: 'Identity' },{Status: 'Open', ParentTab: 'Vitals', subIndex: 3, name: 'Marriage' },{Status: 'Open', ParentTab: 'Vitals', subIndex: 4, name: 'Education' },{Status: 'Open', ParentTab: 'Vitals', subIndex: 5, name: 'Military' },{Status: 'Open', ParentTab: 'Vitals', subIndex: 6, name: 'Current Family' },{Status: 'Open', ParentTab: 'Vitals', subIndex: 7, name: 'Social Media' }];
  @track childrenSubTab = [{Status: 'Open', ParentTab: 'Children', subIndex: 1, name: 'Children With OP' }];
  @track opposingPartySubTab = [{Status: 'Open', ParentTab: 'Opposing Party', subIndex: 1, name: 'OP-Contact' },{Status: 'Open', ParentTab: 'Opposing Party', subIndex: 2, name: 'OP-Identity' },{Status: 'Open', ParentTab: 'Opposing Party', subIndex: 3, name: 'OP-Family' },{Status: 'Open', ParentTab: 'Opposing Party', subIndex: 4, name: 'OP-Education' },{Status: 'Open', ParentTab: 'Opposing Party', subIndex: 5, name: 'OP-Military' },{Status: 'Open', ParentTab: 'Opposing Party', subIndex: 6, name: 'OP-Social Media' },{Status: 'Open', ParentTab: 'Opposing Party', subIndex: 7, name: 'OP-Service of Process' }];
  @track assetSubTab = [{Status: 'Open', ParentTab: 'Assets', subIndex: 1, name: 'Vehicles' },{Status: 'Open', ParentTab: 'Assets', subIndex: 2, name: 'Real Property' },{Status: 'Open', ParentTab: 'Assets', subIndex: 3, name: 'Bank Accounts' },{Status: 'Open', ParentTab: 'Assets', subIndex: 4, name: 'Investment Accounts' },{Status: 'Open', ParentTab: 'Assets', subIndex: 5, name: 'Retirement Accounts' },{Status: 'Open', ParentTab: 'Assets', subIndex: 6, name: 'Life Insurance' },{Status: 'Open', ParentTab: 'Assets', subIndex: 7, name: 'Furniture/Personal Property' },{Status: 'Open', ParentTab: 'Assets', subIndex: 8, name: 'Additional' }];
  @track debtsSubTab = [{Status: 'Open', ParentTab: 'Debts', subIndex: 1, name: 'Credit Cards' },{Status: 'Open', ParentTab: 'Debts', subIndex: 2, name: 'Additional Debts' }];
  @track incomeSubTab = [{Status: 'Open', ParentTab: 'Income', subIndex: 1, name: 'Current Employment' },{Status: 'Open', ParentTab: 'Income', subIndex: 2, name: 'Previous Employment' },{Status: 'Open', ParentTab: 'Income', subIndex: 3, name: 'Income from Benefits' },{Status: 'Open', ParentTab: 'Income', subIndex: 4, name: 'Support Income' },{Status: 'Open', ParentTab: 'Income', subIndex: 5, name: 'Investment Income' },{Status: 'Open', ParentTab: 'Income', subIndex: 6, name: 'Income from Trusts' },{Status: 'Open', ParentTab: 'Income', subIndex: 7, name: 'Rental Income' },{Status: 'Open', ParentTab: 'Income', subIndex: 8, name: 'Other Income' },{Status: 'Open', ParentTab: 'Income', subIndex: 9, name: 'Tax Returns' }];
  @track expensesSubTab = [{Status: 'Open', ParentTab: 'Expenses', subIndex: 1, name: 'Housing Expenses' },{Status: 'Open', ParentTab: 'Expenses', subIndex: 2, name: 'Utilities' },{Status: 'Open', ParentTab: 'Expenses', subIndex: 3, name: 'Food and Supplies' },{Status: 'Open', ParentTab: 'Expenses', subIndex: 4, name: 'Health Care Costs' },{Status: 'Open', ParentTab: 'Expenses', subIndex: 5, name: 'Vehicles/Transportation' },{Status: 'Open', ParentTab: 'Expenses', subIndex: 6, name: 'Monthly Payroll Expenses' },{Status: 'Open', ParentTab: 'Expenses', subIndex: 7, name: 'Children Expenses/Activities' },{Status: 'Open', ParentTab: 'Expenses', subIndex: 8, name: 'Your Education Expenses' },{Status: 'Open', ParentTab: 'Expenses', subIndex: 9, name: 'Maintenance/Child Support' },{Status: 'Open', ParentTab: 'Expenses', subIndex: 10, name: 'Entertainment' },{Status: 'Open', ParentTab: 'Expenses', subIndex: 11, name: 'Legal Expenses' },{Status: 'Open', ParentTab: 'Expenses', subIndex: 12, name: 'Miscellaneous' }];
  @track additionalUploadsSubTab = [{Status: 'Open', ParentTab: 'Additional Uploads', subIndex: 1, name: 'Additional Uploads' }];  
  @track subStepsData = [
    {Status: 'Open', ParentTab: 'Children', subIndex: 1, name: 'Your Children' },
    {Status: 'Open', ParentTab: 'Children', subIndex: 2, name: 'Children Vital Information' },
    {Status: 'Open', ParentTab: 'Children', subIndex: 3, name: 'Extracurricular Activities' },
    {Status: 'Open', ParentTab: 'Children', subIndex: 4, name: 'Medical Providers' }
  ];
  @track subStepsToggleData = [
    {Status: 'Open', ParentTab: 'Children', subIndex: 1, name: 'Your Children' },
    {Status: 'Open', ParentTab: 'Children', subIndex: 2, name: 'Children Vital Information' }
  ];
  @track childrenOtherSubTab = [{Status: 'Open', ParentTab: 'Children', subIndex: 1, name: 'Children from a Different Relationship' }];
  @track selfEmpSectionData = [{Status: 'Open', ParentTab: 'Income', subIndex: 1, name: 'Current Employment' },{Status: 'Open', ParentTab: 'Income', subIndex: 2, name: 'Current Self Employment' },{Status: 'Open', ParentTab: 'Income', subIndex: 3, name: 'Previous Employment' },{Status: 'Open', ParentTab: 'Income', subIndex: 4, name: 'Income from Benefits' },{Status: 'Open', ParentTab: 'Income', subIndex: 5, name: 'Support Income' },{Status: 'Open', ParentTab: 'Income', subIndex: 6, name: 'Investment Income' },{Status: 'Open', ParentTab: 'Income', subIndex: 7, name: 'Income from Trusts' },{Status: 'Open', ParentTab: 'Income', subIndex: 8, name: 'Rental Income' },{Status: 'Open', ParentTab: 'Income', subIndex: 9, name: 'Other Income' },{Status: 'Open', ParentTab: 'Income', subIndex: 10, name: 'Tax Returns' }];
  @track sortedForms = [];
  @track wiredChildrenList;

    @wire(getChildrenList)    
    wiredChildren(result) {
        this.wiredChildrenList = result;
        const { error, data } = result;
        if(data) {
            this.parent1Data ={};
            this.parent2Data ={};
            this.parent1Data = data.filter(child => child.Parent_1__c != null);
            this.parent2Data = data.filter(child => child.Parent_2__c != null);
            this.isLoading = false;
            this.errors = null;
        } else if (error) {
            this.errors = error;
            this.parent1Data = null;
            this.parent2Data = null;
        }
    }
  // Vimeo Videos Variables  
  VimeoId; 
  VimeoHash; 
  portalVideos;
  // Simple Start Variables
  IsSimpleStart=false; 
  showSimpleStartLandingPage=false;
  ShowSimpleStartApplication=false; 
  ShowSimpleStartAddress=false;
  ShowConsent=false;
  ShowWaiting=false;
  ShowRetainerDecision=false;
  IsFeeAgreement=false;
  ShowFeeAgreementLanding=false;
  ShowFeeAgreement=false;
  ShowPaymentLink=false;
  ShowThankYouPage=false;
  openMatterPopup = false;
  ShowClientInterview = false;  
  //platform event related 
  subscription;

  // isEditing set to true when a user edits a field on a grandchild form
  isEditing=false;
  menuClickWhenEditing=false;

  get NotClientInterview() {
    return !this.ShowClientInterview;
  }
  get NotSimpleStart() {
    return !this.IsSimpleStart;
  }
  get NotFeeAgreement() {
    return !this.ShowFeeAgreement;
  }
  get NotFeeAgreementLanding() {
    return !this.ShowFeeAgreementLanding;
    
  }
  get NotShowPaymentLink() {
    return !this.ShowPaymentLink;
  }
  get NotShowThankYouPage() {
    return !this.ShowThankYouPage;
  }
  get NotAdditionalUploads(){
    return this.tabName==='Additional Uploads' ? false : true;
  } 
  get NotAttorneyTransition(){
    return !this.attorneyTransition;
  }   
/*
    steps = [  //this overwrites the regular Customer Interview menu steps
    { label: 'Applicant Vitals', subSteps: [{ label: 'Address' }] },
    { label: 'Consent' },
    { label: 'Result' }
  ];
*/
  get activeIndex() { 
    if (this.ShowSimpleStartApplication) return 0; 
    if (this.ShowConsent) return 1; 
    if (this.ShowRetainerDecision) return 2; 
    return 0; 
  }
  // Compute which SUB-step is active when we're on step 0
  get activeSubIndex() {
    if (this.activeIndex !== 0) return undefined; // no sub-pill for other steps
    if (this.ShowSimpleStartAddress) return 0;    // "Address" pill
    // if (this.ShowSimpleStartApplication) return undefined; // no sub-pill
    // Add more sub-step mappings here if you add them (e.g., Phone -> return 1)
    return undefined;
  }
  @wire(getPortalVideos) wiredGetPortalVideos(result){
    const {error, data} =result;
    if (data) {
      this.portalVideos=data;
    } else if (error){
      this.portalVideos=undefined;
    }
    // set a default video to load when logging into the Portal
    if (this.portalVideos) {
        if (this.portalVideos.find(video => video.Label === 'Contact')){
          this.VimeoId = this.portalVideos.find(video => video.Label === 'Contact').VimeoId__c;     //data is case sensitive
          this.VimeoHash = this.portalVideos.find(video => video.Label === 'Contact').VimeoHash__c; 
        }      
    }
  }
  get srcUrl() {
    if (this.VimeoId && this.VimeoHash){
      let url=`https://player.vimeo.com/video/${this.VimeoId}?h=${this.VimeoHash}&title=0&byline=0&portrait=0`;
      return url;
    }
    return null;
  }
  tabToNavigate ='';
  logoImg = logo;
  profilePicture;
  editIconImg = editIcon;
  matterBackgroundImg = matterBackground
  userImg;
  currentStep = 1;
  currentSubStep = 1;
  clientName;
  matter;
  primaryAttorney;
  primaryParalegal;
  matterIdFromParent;
  clientAccountId;
  loginGradientImg = loginGradient;
  sefEmployee = false;
  fileName = '';
  @track tabName = 'Vitals';
  tempTabName = 'Vitals';
  subTabName;
  managePreviousANDNextButtons = true;
  managePreviousBtn = false;
  matterIdAuto;
  heightOfConnector = 81;
  isAddingChild = false;
  isBadge = false;
  OPValidation = true;
  vitalValidation = true;
  CIFormStatus = 'Open';
  // Responsive variables
  isDesktop = true;   // true when width > 1400px
  isMobile = false;   // true when width <= 1400px
  onResize;
  attorneyTransition=false;
  recordIdToPass; //id to pass to attorneyTransition
  retainingClients; //flag to pass to attorneyTransition

  // userDashboard toggle — set to true inside connectedCallback when user has ≥1 Matter.
  showUserDashboard = false;
  // Raw Account from getCurrentUserDetail — passed down to <c-user-dashboard> via @api.
  @track currentUserAccount;

  // ── Dashboard sub-pages (Item B/C/E from Phase 2 plan) ─────────────
  // TODO: when a 4th sub-view is added, refactor these booleans into a
  // single activeView string. See Phase 2 plan "Routing strategy".
  showFaq = false;
  showAllUpdates = false;

  // Set true once the dashboard routes the user into a sub-flow (CI, FA,
  // PaymentLink, etc.). Drives the "← Back to Dashboard" link in the
  // global header. Reset by returnToDashboard().
  canReturnToDashboard = false;

  connectedCallback() {   
    let sendCreditRequest, creditCheckComplete, creditDecision, creditApplicant, sendFeeAgreement, signingURL, agreementStatus, invoiceURL, trustBalance, feeAgreementAmount;
    getAllMatterDetailsForPortalUser().then(result=>{
      this.allMatterCases = result;
      this.openMatterPopup = false;
      this.IsSimpleStart=false;  //  since no matters is the condition for SimpleStart 
      this.IsFeeAgreement=false;
      this.ShowSimpleStartLandingPage=false;  //the default form to display
      getCurrentUserDetail().then(result=>{ // to support the SimpleStart forms
        this.currentUserAccount = result; // passed to <c-user-dashboard> via @api
        this.clientAccountId=result.Id;
        this.clientName = result.Name;
        this.primaryAttorney = result.Responsible_Attorney__r?.Name;
        this.primaryParalegal = result.Responsible_Paralegal__r?.Name;        
        sendCreditRequest = result.Send_Credit_Request__c;
        creditCheckComplete = result.Credit_Check_Complete__c;
        // Need to check for Allow Fee Agreement and display if true
        sendFeeAgreement = result.Allow_Fee_Agreement__c;
        signingURL = result.Fa_Portal_Signing_URL__c;
        agreementStatus = result.FA_Portal_Agreement_Status__c;
        invoiceURL = result.Invoice_Retainer_URL__c;
        trustBalance = result.Timesolv_TrustAccount_Balance__c;
        feeAgreementAmount = result.Total_Fee_Agreement_Amount__c
        creditCheckComplete = result.Credit_Check_Complete__c;
        // Need to check for credit decision
        creditDecision = result.Credit_Decision__c;
        creditApplicant = result.Credit_Applicant__c;
        if (this.allMatterCases.length>0){ //check for the Retaining_Clients__c, Not_Retaining_Clients__c flags--present attorney transition page if either are true
          for (const aMatter of this.allMatterCases) {
            if ((aMatter.Primary_Attorney__r.Retaining_Clients__c===true || aMatter.Primary_Attorney__r.Not_Retaining_Clients__c===true) && (aMatter.Retaining_Client_Date__c==null)) { //if there is any response don't show the attorney transition page
              this.retainingClients = aMatter.Primary_Attorney__r.Retaining_Clients__c==true ? "true" : "false";
              this.recordIdToPass=aMatter.Id;                
              this.attorneyTransition=true;
              return;  //do not proceed
            }
          }
        }        
          if ( sendCreditRequest === true && creditCheckComplete === true && signingURL === undefined && this.allMatterCases.length === 0 )  {   //they have already applied for Simple Start and received a decision            
            this.openMatterPopup = false;
            this.IsSimpleStart=true;  //  since no matters is the condition for SimpleStart 
            this.ShowRetainerDecision=true;  //the default form to display        
          }      
          else if ( sendCreditRequest === true && creditCheckComplete === false && creditApplicant!=='Third Party') {   //a client can have a matter and still apply for Simple Start
            this.openMatterPopup = false;
            this.IsSimpleStart=true;  //  since no matters is the condition for SimpleStart 
            this.ShowSimpleStartLandingPage=true;  //the default form to display                   
          } 
          else if (sendFeeAgreement === true && (sendCreditRequest === false || creditCheckComplete === true) && agreementStatus === undefined) {
            this.IsSimpleStart = false;
            this.IsFeeAgreement = true;
            this.ShowFeeAgreementLanding = true;
          }
          else if ( sendFeeAgreement === true && (agreementStatus === 'Out for Signature' || agreementStatus === 'Cancelled' || agreementStatus === 'Expired') ) {
            this.ShowFeeAgreementLanding = false;
            this.IsFeeAgreement=true;
            this.ShowFeeAgreement = true;
          }
          else if ( (trustBalance === undefined || trustBalance !== feeAgreementAmount) && (agreementStatus !== 'Out for Signature' && agreementStatus !== 'Cancelled' && agreementStatus !== 'Expired' && agreementStatus !== undefined) && creditDecision !== 'Gold - 0% Retainer' ) {
            this.IsFeeAgreement = true;
            this.ShowPaymentLink = true;
            console.log(creditDecision);
            console.log(trustBalance);
          }
          else if ( ( this.allMatterCases.length === 0 && (creditDecision === 'Gold - 0% Retainer' ||trustBalance === feeAgreementAmount) ) && (agreementStatus !== 'Out for Signature' && agreementStatus !== 'Cancelled' && agreementStatus !== 'Expired' && agreementStatus !== undefined) ) {
            this.IsFeeAgreement = true;
            this.ShowThankYouPage = true;
            console.log('thank you');
          }
          else if (this.allMatterCases && this.allMatterCases.length >= 1) {
            // userDashboard handles both single- and multi-matter selection now.
            // Old behaviour (kept for reference, can be removed once dashboard ships):
            //   length === 1 → ShowClientInterview + getDetailsSingleMatter()
            //   length  > 1 → openMatterPopup = true
            this.openMatterPopup = false;
            this.showUserDashboard = true;
          }
          
          if (this.IsSimpleStart){ //overwrite the Customer Interview menu steps with the Simple Start menu steps
                this.steps = [
                { label: 'Applicant Vitals', subSteps: [{ label: 'Address' }] },
                { label: 'Consent' },
                { label: 'Result' }
              ];
              if (this.portalVideos) {
                this.VimeoId = this.portalVideos.find(video => video.Label === 'Simple Start').VimeoId__c;     //data is case sensitive
                this.VimeoHash = this.portalVideos.find(video => video.Label === 'Simple Start').VimeoHash__c;       
              }
          } else if (this.IsSimpleStart === false ) {
            //this.manageCIFormStatus();  //no matter has been selected at this point do not call this.manageCIFormStatus
          }

      });
    })
    .catch(error => {
      createFutureErrorRecord( {exceptionMessage: error.message ?? error.body.message, stackTrace: error.stack ?? error.body.stackTrace, lineNum: 0, errortype: 'Javascript', 
        procname: 'virtualAccountCreater.getAllMatterDetailsForPortalUser'}) ;
      console.error('Exception thrown:  ', error, 'stack trace:  ', error.stack);
    }); 
      if (this.isDesktop) {
        createThread()
          .then(result => {
              const data = JSON.parse(result);
              this.threadId = data.id;
              this.appendMessage(
                'Welcome to Modern Family Law!<br><br>I am an AI chatbot that can help answer any questions you have as you go through your onboarding activities. Let me know if you need any assistance.',
                'bot',
                true
              );
          })
          .catch(error => {
            createFutureErrorRecord( {exceptionMessage: error.message ?? error.body.message, stackTrace: error.stack ?? error.body.stackTrace, lineNum: 0, errortype: 'Javascript', procname: 'virtualAccountCreater.createThread'}) ;
            console.error('Exception thrown:  ', error, 'stack trace:  ', error.stack);            
          });            
      }                
    this.updateDevice();
    this.onResize = () => this.updateDevice(); // keep up to date on resize
    window.addEventListener('resize', this.onResize);
    // console.log('innerWidth:', window.innerWidth, 'px'); 
    // code for handling platform events
    /*try {
        // Check if EMP API is available
        const isEmpApiEnabled = isEmpEnabled();
        if (!isEmpApiEnabled) {
            console.log('The EMP API is not enabled.');
            return;
        }
        // Handle EMP API debugging and error reporting
        setDebugFlag(true);
        onError((error) => {
            console.log('EMP API error', error);
        });

        // Subscribe to Manufacturing Event plaform event
        try {
            this.subscription = subscribe(
                MATTERCREATEDEVENT,
                -1,
                (event) => {
                    this.handleEvent(event);
                    //this.getDetailsSingleMatter();  //will retrieve the matter into this component
                }
            );
        } catch (error) {
            console.log('EMP API error: failed to subscribe', error);
        }
    }
    catch(error) {
        createFutureErrorRecord( {exceptionMessage: error.message ?? error.body.message, stackTrace: error.stack ?? error.body.stackTrace, lineNum: 0, errortype: 'Javascript', procname: 'virtualAccountCreater platform event registration'}) ;
        console.error('Exception thrown:  ', error, 'stack trace:  ', error.stack);    
    } */
  }

    /*handleEvent(event) {
        console.log('event.data.payload.MatterId__c',event.data.payload.MatterId__c);
        console.log('event.data.payload.UserId__c',event.data.payload.UserId__c);        
        this.getDetailsSingleMatter();  //will retrieve the matter into this component
    }

  disconnectedCallback() {
      if (this.subscription) {
          unsubscribe(this.subscription);  //unsubscribe from the MatterCreatedEvent
      }
  }*/
 
  async openChat() {
  // const data = JSON.parse(await createThread());
  // const threadId = data.id;

    await MobileChatModal.open({
      size: 'large',
      label: 'How can I help?',
      srcUrl: this.srcUrl,
      // threadId 
    });
  }

  updateDevice() {
    const width = window.innerWidth; // use screen.width if you truly want physical screen size
    if (width > 1300) {
      this.isDesktop = true;
      this.isMobile = false;
      // console.log('Desktop');
    } else {
      this.isDesktop = false;
      this.isMobile = true;
      // console.log('Mobile');
    }
  }

  getDetailsSingleMatter () {
    getMatterDetailsForPortalUser().then(result=>{
      this.fillMatterData(result);
      updateMatterDateTime({matter : this.matterData})
      this.manageCIFormStatus();
    })
    .catch(error => {
      createFutureErrorRecord( {exceptionMessage: error.message ?? error.body.message, stackTrace: error.stack ?? error.body.stackTrace, lineNum: 0, errortype: 'Javascript', procname: 'virtualAccountCreater.getDetailsSingleMatter'}) ;
      console.error('Exception thrown:  ', error, 'stack trace:  ', error.stack);            
    }); 
  }

  fillMatterData(result){
    this.clientName = result.Client_Name__r.Name;
    this.matter = result.Matter_ID_Full__c;
    this.matterIdAuto = result.Matter_ID_Auto__c;
    this.primaryAttorney = result.Primary_Attorney__r.Name;
    this.primaryParalegal = result?.Primary_Paralegal__r?.Name;
    this.matterIdFromParent = result.Id;
    this.profilePicture = result.Client_Name__r.Photo_URL__c ?? uploadBlock ;
    this.clientId = result.Client_Name__r.Id;
    this.matterData = result;
  }

  manageCIFormStatus () {
    if (this.matterIdFromParent==undefined || this.matterIdFromParent==null ||this.matterIdFromParent =='' ) {return;}  //finding that this.matterIdFromParent is sometimes not set
    getCIFormStatus({matterId : this.matterIdFromParent}).then(statusResult=>{
      const orderMap = desiredOrder.reduce((map, item, index) => {
            map[item] = index;
            return map;
      }, {});
      this.sortedForms = [...statusResult].sort((a, b) => {
            const aIndex = orderMap[a.Subject] ?? Number.MAX_SAFE_INTEGER;
            const bIndex = orderMap[b.Subject] ?? Number.MAX_SAFE_INTEGER;
            return aIndex - bIndex;
      });
      if (this.sortedForms) {
        let openStatusRecord = this.sortedForms?.find(item => item.Status === 'Open');
        let openStatusRecordSubject;
        if (openStatusRecord) {
          openStatusRecordSubject = openStatusRecord?.Subject;
        }
        if(openStatusRecord && this.steps.find(step => step.name === openStatusRecord.Subject)){ //debugging here
          this.tabName = openStatusRecord.Subject;
          const stepMap = {
            'Vitals': 1,
            'Opposing Party': 2,
            'Children': 3,
            'Assets': 4,
            'Debts': 5,
            'Income': 6,
            'Expenses': 7,
            'Additional Uploads':8
          };
          const stepNumber = stepMap[this.tabName];  //go to the first open step
          if (stepNumber) {
            this.currentStep = stepNumber;
            this.currentSubStep = 1;
            // Special case for 'Vitals'
            if (this.tabName === 'Vitals') {
              this.callEditCIFormStatus(this.matterIdFromParent, 'Contact');
              console.log('Vitals');
            }
          }
          this.callEditCIFormStatus(this.matterIdFromParent,this.tabName);      
          } else {
              const subTabs = [
                { list: this.vitalSubTab, step: 1 },
                { list: this.opposingPartySubTab, step: 2 },
                { list: this.childrenSubTab, step: 3 },
                { list: this.assetSubTab, step: 4 },
                { list: this.debtsSubTab, step: 5 },
                { list: this.incomeSubTab, step: 6 },
                { list: this.expensesSubTab, step: 7 },
                { list: this.additionalUploadsSubTab, step: 8 }            
              ];
              for (const { list, step } of subTabs) {
                const found = list.find(subStep => subStep.name === openStatusRecordSubject);  //list is just the names of the parent menus and will not contain openStatusRecordSubject='CI Form:  Additional'
                if (found) {
                  this.tabName = found.ParentTab;
                  this.subTabName = found.name;
                  if (this.portalVideos.find(video => video.Label === this.subTabName)){
                    this.VimeoId = this.portalVideos.find(video => video.Label === this.subTabName).VimeoId__c;     //data is case sensitive
                    this.VimeoHash = this.portalVideos.find(video => video.Label === this.subTabName).VimeoHash__c;            
                  }
                  this.addingSubTab();
                  this.currentStep = step;
                  this.currentSubStep = found.subIndex;
                  break;
            }
          }
          if(this.childrenSubTab === 'Current Employment'){
            this.callEditCIFormStatus(this.matterIdFromParent,'Current Self Employment');
          }        
        }
        this.computeSteps();
      }
    }) 
    .catch(error => {
      createFutureErrorRecord( {exceptionMessage: error.message ?? error.body.message, stackTrace: error.stack ?? error.body.stackTrace, lineNum: 0, errortype: 'Javascript', procname: 'virtualAccountCreater.manageCIFormStatus'}) ;
      console.error('Exception thrown:  ', error, 'stack trace:  ', error.stack);
    });
  }

  computeSteps() { // only called by manageCIFormStatus
    try {
      this.steps = this.steps.filter((step) => { //this.steps are the main forms that are display in the HTML
          const result = this.sortedForms.some(item => item.Subject.includes(step.name));  //this.sortedForms are the forms returned from the task object fetch so these are the only forms to be displayed
          if (result) {
            return true; 
          }
          return false; 
      });
      this.steps.forEach(reIndex);  //TODO      
      function reIndex(item, idx, arr) {//reIndex the this.steps array
        arr[idx].index = idx+1;
      }
    }
    catch(error) {
      createFutureErrorRecord( {exceptionMessage: error.message ?? error.body.message, stackTrace: error.stack ?? error.body.stackTrace, lineNum: 0, errortype: 'Javascript', procname: 'virtualAccountCreater.computeSteps'}) ;
      console.error('Exception thrown:  ', error, 'stack trace:  ', error.stack);
    };
  }

  get computedSteps() { //mostly used to apply styling to steps and sub-steps -- referenced by mobileSteps and the step HTML markup
    try {
    return this.steps.map((step) => {
      const isCurrent = step.index === this.currentStep;
      const isCompleted = step.index < this.currentStep;
      const subSteps = step.subSteps.map((subStep) => {
        const isSubCurrent = isCurrent && subStep.subIndex === this.currentSubStep;
        const isSubCompleted = isCompleted || (this.currentStep >= step.index && subStep.subIndex < this.currentSubStep);
        return {
          ...subStep,
          subCircleClass: `sub-circle ${isSubCurrent ? 'active' : ''} ${
            isSubCompleted ? 'completed' : ''
          }`,
          subStepNameClass: `sub-step-name ${isSubCurrent ? 'active' : ''}`,
        };
      });
      let connectorHeight = this.heightOfConnector;
      if (step.name === 'Additional Uploads') {  //Additional Uploads
        connectorHeight = subSteps.length * 31;
      } else {
        connectorHeight = this.heightOfConnector + (subSteps.length * 31);
      }
      return {
        ...step,
        circleClass: `circle ${isCurrent ? 'active' : ''} ${
          isCompleted ? 'completed' : ''
        }`,
        stepNameClass: `step-name ${isCurrent ? 'active' : ''}`,
        connectorClass: `connector ${isCompleted ? 'completed' : ''}`,
        connectorStyle: `height: ${connectorHeight}px;`,
        subSteps,
      };
    })
  }
    catch(error) {
        createFutureErrorRecord( {exceptionMessage: error.message ?? error.body.message, stackTrace: error.stack ?? error.body.stackTrace, lineNum: 0, errortype: 'Javascript', procname: 'virtualAccountCreater.get computedSteps'}) ;
        console.error('Exception thrown:  ', error, 'stack trace:  ', error.stack);    
    }
  }

  getAllSubSteps(stepIndex, step) {
    if (Array.isArray(step.subSteps) && step.subSteps.length) return step.subSteps;

    if (Array.isArray(step.subStepNames)) {
      return step.subStepNames.map((name, i) => ({ name, subIndex: i + 1 }));
    }
    return [];
  }

  get mobileSteps() {
    const curStep = this.currentStep;
    const curSub  = this.currentSubStep;

    const src = this.steps && this.steps.length ? this.steps : (this.computedSteps ?? []);

    return (src ?? []).map((step, i) => {

      const index = Number(step.index ?? i + 1);

      // Ensure every step has substeps for the mobile menu
      const subs = this.getAllSubSteps(index, step);

      return {
        ...step,
        index,
        // Unique, stable keys for each direct child rendered in the for:each loop
        headerKey:  `hdr-${index}`,   // <lightning-menu-subheader key={step.headerKey}>
        parentKey:  `step-${index}`,  // <lightning-menu-item key={step.parentKey}>
        dividerKey: `div-${index}`,   // <lightning-menu-divider key={step.dividerKey}>

        // Parent-step menu item
        value: `step:${index}`,
        disabled: step.disabled ?? false,
        isCurrent: index === curStep && (curSub === 1 || !curSub),

        // Substeps mapped with values/labels/keys
        subSteps: subs.map((sub, j) => {
          const subIndex = Number(sub.subIndex ?? j + 1);
          const name = sub.name ?? `Substep ${subIndex}`;
          return {
            ...sub,
            name,
            subIndex,
            key:   `sub-${index}-${subIndex}`,   // <lightning-menu-item key={sub.key}>
            value: `sub:${index}:${subIndex}`,   // parsed by handleMobileMenuSelect
            label: `• ${name}`,                  // shows a bullet indent
            disabled: sub.disabled ?? false,
            isCurrent: index === curStep && subIndex === curSub
          };
        })
      };
    });
  }

  handleMobileMenuSelect(event) {
     if (this.isEditing) {
      this.menuClickWhenEditing = true;
      return; // block navigation
    }

    const value = event.detail?.value; 
    if (!value) return;

    const [kind, a, b] = value.split(':');
    if (kind === 'step') {
      const stepIndex = Number(a);
      // Guard against out-of-range (common source of “it doesn’t work”)
      if (!Number.isFinite(stepIndex) || !this.steps?.[stepIndex - 1]) return;

      this.steps[stepIndex - 1].isIcon = false;
      this.steps[stepIndex - 1].iconName = 'utility:minimize_window';
      this.steps[stepIndex - 1].sectionCSS = 'expand-icon';
      this.currentStep = stepIndex;
      this.currentSubStep = 1;      // first substep
      this.handleTabPage();
    } else if (kind === 'sub') {
      const stepIndex = Number(a);
      const subIndex = Number(b);
      if (!Number.isFinite(stepIndex) || !Number.isFinite(subIndex)) return;

      this.currentStep = stepIndex;
      this.currentSubStep = subIndex;
      this.handleTabPage();
    }
  }
  
  handleValidationOP (event) {
    if (event.detail.validation) {
      this.OPValidation = false;
    } else {
      this.OPValidation = true;
    }
    this.OPvalidateList = event.detail.value1;
  }

  handleValidationVital (event) {
    if (event.detail.validation) {
      this.vitalValidation = false;
    } else {
      this.vitalValidation = true;
    }
    this.VITALvalidateList = event.detail.value1;
  }

  callEditCIFormStatus(matterid,tabName){
    editCIFormStatus({matterId : matterid,CIForm : tabName})
      .then(statusEditResult=>{
        console.log('getting status::',statusEditResult);        
      })
      .catch(error => {
      createFutureErrorRecord( {exceptionMessage: error.message ?? error.body.message, stackTrace: error.stack ?? error.body.stackTrace, lineNum: 0, errortype: 'Javascript', procname: 'virtualAccountCreater.callEditCIFormStatus'}) ;
      console.error('Exception thrown:  ', error, 'stack trace:  ', error.stack);
      });
  }

  handleNext() {
    try {
      if(this.tabName === 'Vitals' || this.tabName === 'Opposing Party' ){
          if (this.OPValidation && this.vitalValidation ) {
            this.moveNext();
        } else {
          if (!this.vitalValidation && this.tabName === 'Vitals') {
            this.validateFieldsOfVital();
          }
          if (!this.OPValidation && this.tabName === 'Opposing Party') {
            this.validateFieldsOfOpposingParty();
          }
        }
      } else {
          this.moveNext();
      } }
    catch(error)  {
      createFutureErrorRecord( {exceptionMessage: error.message ?? error.body.message, stackTrace: error.stack ?? error.body.stackTrace, lineNum: 0, errortype: 'Javascript', procname: 'virtualAccountCreater.handleNext'}) ;
      console.error('Exception thrown:  ', error, 'stack trace:  ', error.stack);
    };
  }

  moveNext(){
    try {
      const currentStep = this.steps.find((step) => step.index === this.currentStep);
      if (currentStep.subSteps.length > 0 && this.currentSubStep < currentStep.subSteps.length) {
        this.currentSubStep = (this.currentSubStep || 0) + 1;
      } else if (this.currentStep < this.steps.length-1) { //The last menu entry is always additional uploads but we don't want to navigate to that via the Save & Continue Button
        this.currentStep += 1;
        this.currentSubStep = null;
      }
      this.callEditCIFormStatus(this.matterIdFromParent,this.subTabName);
      this.callEditCIFormStatus(this.matterIdFromParent,currentStep.name);
      this.handleTabPage();
    }
    catch(error)  {
      createFutureErrorRecord( {exceptionMessage: error.message ?? error.body.message, stackTrace: error.stack ?? error.body.stackTrace, lineNum: 0, errortype: 'Javascript', procname: 'virtualAccountCreater.moveNext'}) ;
      console.error('Exception thrown:  ', error, 'stack trace:  ', error.stack);
    };
  }

 validateFieldsOfOpposingParty() {
    const validation = this.OPvalidateList[0];
    let errorMessages = [];
    const validationChecks = [
      { field: 'emailErrorOP', message: 'Please check email field format and it is required.' },
      { field: 'phoneErrorOP', message: 'Please check mobile field format.' },
      { field: 'numberErrorOP', message: 'Please check Length of Residence field format.' },
      { field: 'yearsOfCollegeErrorOP', message: 'Please check year of college field value should be min="0" max="20".' },
      { field: 'yearsOfGraduateSchoolErrorOP', message: 'Please check years Of Graduate School field value should be min="0" max="20".' },
      { field: 'weightErrorOP', message: 'Please check weight field value should be min="0" max="500".' },
      { field: 'heightErrorOP', message: 'Please enter height in feet and inches such as 5\'7".' },
      { field: 'isMalingAddressOP', message: 'Please check address fields; it is required.' }
    ];
    validationChecks.forEach(({ field, message }) => {
      if (!validation[field]) {
        errorMessages.push(message);
      }
    });
    if (errorMessages.length > 0) {
      this.showToast('ERROR IN OPPOSING PARTY SECTION', errorMessages.join('\n'), 'error');
    }
  }

  validateFieldsOfVital() {
    const validation = this.VITALvalidateList[0];
    let errorMessages = [];
    const validationChecks = [
      { field: 'emailError', message: 'Please check email field format and it is required.' },
      { field: 'phoneError', message: 'Please check mobile field format.' },
      { field: 'numberError', message: 'Please check Length of Residence field format.' },
      { field: 'yearsOfCollegeError', message: 'Please check year of college field value should be min="0" max="20".' },
      { field: 'yearsOfGraduateSchoolError', message: 'Please check years Of Graduate School field value should be min="0" max="20".' },
      { field: 'isMalingAddress', message: 'Please check address fields; it is required.' },
      { field: 'socialSecurityError', message: 'Please check correct Social Security Number of required length.' },
      { field: 'childrenOfThisRelationshipError', message: 'Please enter a valid number of children from this relationship.' }
    ];
    validationChecks.forEach(({ field, message }) => {
      if (!validation[field]) {
        errorMessages.push(message);
      }
    });
    if (errorMessages.length > 0) {
      this.showToast('ERROR IN VITAL SECTION', errorMessages.join('\n'), 'error');
    }
  }

  handlePrevious() {
    try {
    if (this.OPValidation && this.vitalValidation) {
      const currentStep = this.steps.find((step) => step.index === this.currentStep);
      if (currentStep.subSteps.length > 0 && this.currentSubStep > 1) {
        this.currentSubStep -= 1;
      } else if (this.currentStep > 1) {
        this.currentStep -= 1;
        const previousStep = this.steps.find(
          (step) => step.index === this.currentStep
        );
        this.currentSubStep = previousStep.subSteps.length || null;
      }
      this.handleTabPage();
    }
    } catch(error)  {
      createFutureErrorRecord( {exceptionMessage: error.message ?? error.body.message, stackTrace: error.stack ?? error.body.stackTrace, lineNum: 0, errortype: 'Javascript', procname: 'virtualAccountCreater.handlePrevious'}) ;
      console.error('Exception thrown:  ', error, 'stack trace:  ', error.stack);
    };
  }

  get managePreviousButtons () {
    if (this.tabName === 'Children' || this.tabName === 'Expenses') {
      return false;
    } else if (this.tabName === 'Additional Uploads') {
      return false;
    }
    else if (this.currentStep >= 1 && this.subTabName !== 'Contact') {
      return true;
    }
    return false;
  }

  handleTabPage () {
    try {
      this.tabName = this.steps[this.currentStep - 1].name;
      if (this.isBadge) {
        this.isBadge = false;
        this.currentSubStep = 1;
      }
      this.addingSubTab();
      if (this.steps[this.currentStep - 1].subSteps.length > 0) {  //Additional Uploads has not substeps so this is not entered
        this.subTabName = this.steps[this.currentStep - 1].subSteps[this.currentSubStep - 1].name;
        if (this.portalVideos.find(video => video.Label === this.subTabName)){
          this.VimeoId = this.portalVideos.find(video => video.Label === this.subTabName).VimeoId__c;      //data is case sensitive
          this.VimeoHash = this.portalVideos.find(video => video.Label === this.subTabName).VimeoHash__c;        
        }
      }
      getIndividualCIFormStatus({matterId : this.matterIdFromParent,CIForm : this.subTabName}).then(statusIdividualResult=>{
        this.CIFormStatus = statusIdividualResult[0]?.Status;
      });
      if (this.tabName === 'Children' && (this.subTabName === 'Your Children' || this.subTabName === 'Social Media')) {
        this.manageNextBtn = false;
        this.managePreviousBtn = false;
      } else if (this.subTabName === 'Children Vital Information' || (this.tabName === 'Vitals' && this.subTabName === 'Social Media') || this.tabName === 'Assets' || this.tabName === 'Income' || this.tabName === 'Debts' || (this.tabName === 'Opposing Party' && this.subTabName === 'OP-Service of Process')) {
        this.manageNextBtn = false;
        this.managePreviousBtn = false;
      } else {
        this.manageNextBtn = true;
        this.managePreviousBtn = true;
      }
    } catch(error)  {
      createFutureErrorRecord( {exceptionMessage: error.message ?? error.body.message, stackTrace: error.stack ?? error.body.stackTrace, lineNum: 0, errortype: 'Javascript', procname: 'virtualAccountCreater.handleTabPage '}) ;
      console.error('Exception thrown:  ', error, 'stack trace:  ', error.stack);
    };
  }

  get manageNextButtons () {    
    if (this.tabName === 'Children' || this.tabName === 'Assets' || this.tabName === 'Income' || this.tabName === 'Debts') {
      return false;
    } else if (this.tabName === 'Expenses' && this.subTabName === 'Miscellaneous') {
      return false;
    } else if ( this.tabName === 'Vitals' && this.subTabName === 'Social Media'){
      return false;
    } else if ( this.tabName === 'Additional Uploads'){
      return false;
    }    
    return true;
  }

  handleSimpleStartForm(event) {
    console.log('simpleStart detail:', event.detail);

    this.ShowSimpleStartLandingPage = false;
    this.ShowSimpleStartApplication = false;
    this.ShowSimpleStartAddress = false;
    this.ShowConsent = false;
    this.ShowWaiting = false;
    this.ShowRetainerDecision = false;
    this.ShowFeeAgreementLanding = false;
    this.ShowFeeAgreement = false;
    this.ShowPaymentLink = false;
    this.ShowThankYouPage = false;

    const step = event.detail?.step || event.detail;

    switch (step) {
        case 'ShowSimpleStartLandingPage': this.ShowSimpleStartLandingPage = true; break;
        case 'ShowSimpleStartApplication': this.ShowSimpleStartApplication = true; break;
        case 'ShowSimpleStartAddress': this.ShowSimpleStartAddress = true; break;
        case 'ShowConsent': this.ShowConsent = true; break;
        case 'ShowWaiting': this.ShowWaiting = true; break;
        case 'ShowRetainerDecision': this.ShowRetainerDecision = true; break;
        case 'ShowFeeAgreementLanding': this.ShowFeeAgreementLanding = true; this.IsFeeAgreement = true; break;
        case 'ShowFeeAgreement': this.ShowFeeAgreement = true; break;
        case 'ShowPaymentLink': this.ShowPaymentLink = true; break;
        case 'ShowThankYouPage': this.ShowThankYouPage = true; this.IsFeeAgreement = true; break;
        case 'ShowClientInterview': this.ShowClientInterview = true; break;
    }

    // hide Simple Start column when Fee Agreement shows
    this.IsSimpleStart = !['ShowFeeAgreement', 'ShowFeeAgreementLanding', 'ShowPaymentLink', 'ShowThankYouPage', 'ShowClientInterview'].includes(step);
  }   

  handleContinueToInterview(event) {
    this.getDetailsSingleMatter();
    this.IsFeeAgreement=false;
    this.ShowClientInterview=true;
  }

  handleVideoChange(event) {  //these events come from childrenSubPage.js and are tied to children sub-forms
    const videoname = event.detail;
    console.log('event:  ',JSON.stringify(event));
    if (this.portalVideos.find(video => video.Label === videoname)){
      this.VimeoId = this.portalVideos.find(video => video.Label === videoname).VimeoId__c;     //data is case sensitive
      this.VimeoHash = this.portalVideos.find(video => video.Label === videoname).VimeoHash__c;  
    }
  }

  handleChildInParent (event) {
    let childrenStepAdd = this.steps.find(step => step.name === 'Children');
    if (childrenStepAdd) {
      childrenStepAdd.subSteps = this.subStepsData;
    }
    this.isAddingChild = true;
    this.receivedValue = event.detail;
    if (event.detail.field) {
      const childrenStep = this.steps.find(step => step.name === 'Children');
      this.subStepsData[0].name = event.detail.value;
      this.subStepsData[1].name = event.detail.tabName;
      if (childrenStep){                                                                                        
        childrenStep.subSteps = this.subStepsData;
        this.handleNext(); 
      }
    }
  }

  handleResetPrgressChild (event) { // Don event originates from childrenSubPage.js when the slider is selected between "Children from Relationship with Opposing Party" and "Children from Relationship with Other"
    if (event.detail.field) {
      const childrenStep = this.steps.find(step => step.name === 'Children');
      this.subStepsToggleData[0].name = event.detail.value;  
      this.subStepsToggleData[1].name = event.detail.tabName;
      if (childrenStep) {
        if (this.subStepsToggleData[0].name === 'Children from a Different Relationship') {
          childrenStep.subSteps = this.childrenOtherSubTab;
        } else {
          childrenStep.subSteps = this.childrenSubTab;
        }
      }
    }
  }

  handleDoneWithTheProvider(event){
    if (event.detail.field) {
      const childrenStep = this.steps.find(step => step.name === 'Children');
      this.subStepsToggleData[0].name = event.detail.value;
      this.subStepsToggleData[1].name = event.detail.tabName;     
      if (childrenStep) {
        if (this.subStepsToggleData[0].name === 'Children from a Different Relationship') {
          childrenStep.subSteps = this.childrenOtherSubTab;
        } else {
          childrenStep.subSteps = this.childrenSubTab;
        }
      }
      this.currentStep = 3;
      this.currentSubStep = 1;
    }
  }

  handleToggleInParent (event) {
    let childrenStepAdd = this.steps.find(step => step.name === 'Children');
    if (childrenStepAdd) {
      childrenStepAdd.subSteps = this.subStepsToggleData;
      if(event.detail.toggle){
        childrenStepAdd.subSteps = this.childrenOtherSubTab;
      }
    }
    this.isAddingChild = true;
    if (event.detail.field) {
      const childrenStep = this.steps.find(step => step.name === 'Children');
      this.subStepsToggleData[0].name = event.detail.value;
      this.subStepsToggleData[1].name = event.detail.tabName;
      if (childrenStep) {
        childrenStep.subSteps = this.subStepsToggleData;
        if (!event.detail.toggle) {          
          this.handleNext();
        } else {
          this.currentStep = 3;
          this.currentSubStep = 1;
          this.handleTabPage();
        }
      }
    }
  }

  get manageButtons () {
    if (this.subTabName === 'Extracurricular Activities' || this.subTabName === 'Medical Providers') {
      return false;
    }
    return true;
  }

  handleSaveChildInParent (event) {
    if (event.detail) {
      this.managePreviousANDNextButtons = true;
      this.handleNext();
    }
  }

  handleCancelChildInParent (event) {
    if (event.detail) {
      this.handlePrevious();
    }
  }

  get manageNextANDSAVEButtons () {
    if (this.tabName === 'Vitals' && this.subTabName === 'Social Media') {
        return true;
    }
    return false;
  }

  handleSubmitVitalSection (event) {
    try {
      if (event.detail) {
        this.isBadge = true;
        this.manageNextBtn = true;
        this.handleNext();
        this.manageNextBtn = true;
      }
    }
    catch(error) {
      createFutureErrorRecord( {exceptionMessage: error.message ?? error.body.message, stackTrace: error.stack ?? error.body.stackTrace, lineNum: 0, errortype: 'Javascript', procname: 'virtualAccountCreater.handleSubmitVitalSection'}) ;
    };
  }

  handlenewprofilephoto (event) {
    if (event.detail) {
      this.profilePicture = event.detail;
    }
  }

  get progressBarClass() {
    return `progress-bar ${this.isEditing ? 'is-editing' : ''}`;
  }

  get editWarningClass() {
    return `editing-warning ${this.menuClickWhenEditing ? 'edit-active' : ''}`;
  }

  displayVitalsSubChildren() { //open the Vitals sub menu to make it obvious that there's more to complete
    const stepIndex = 1;
    this.steps[stepIndex - 1].isIcon = false;
    this.steps[stepIndex - 1].iconName = 'utility:minimize_window';
    this.steps[stepIndex - 1].sectionCSS = 'expand-icon';
    this.currentStep = stepIndex;
    this.currentSubStep = 1;  //start at the first substep under the parent step
    this.handleTabPage();
  }

  handleStepClick(event) {
    if (this.isEditing) {
      this.menuClickWhenEditing = true;
      return; // block navigation
    }
    const stepIndex = Number(event.currentTarget.dataset.stepIndex);
    this.steps[stepIndex - 1].isIcon = false;
    this.steps[stepIndex - 1].iconName = 'utility:minimize_window';
    this.steps[stepIndex - 1].sectionCSS = 'expand-icon';
    this.currentStep = stepIndex;
    this.currentSubStep = 1;  //start at the first substep under the parent step
    this.handleTabPage();
  }

  handleSubStepClick(event) {
    if (this.isEditing) {
      this.menuClickWhenEditing = true;
      return; // block navigation
    }

    const stepIndex = Number(event.currentTarget.dataset.stepIndex);
    const subIndex = Number(event.currentTarget.dataset.subIndex);
    this.currentStep = stepIndex;
    this.currentSubStep = subIndex;
    this.handleTabPage();
  }

  stopNavigateSubStep (event) {
    event.stopPropagation();
  }

  removeOtherSubSteps(){ //remove the submenu items (subSteps) under the main menu items that are not in current focus
    try {
        let otherStep;    
        if (this.tabName !== 'Vitals') {
          const vitalResult = this.steps.some(item => item.name.includes("Vitals"));
          if (vitalResult) {
              otherStep = this.steps.find(step => step.name === 'Vitals');
              otherStep.subSteps = [];
          }    
        }
        if (this.tabName !== 'Opposing Party') {        
          const opposingResult = this.steps.some(item => item.name.includes("Opposing Party"));
          if (opposingResult) {
            otherStep = this.steps.find(step => step.name === 'Opposing Party');
            otherStep.subSteps = [];
          }
        }
        if (this.tabName !== 'Children') {           
          const childResult = this.steps.some(item => item.name.includes("Children"));
          if (childResult) {
            otherStep = this.steps.find(step => step.name === 'Children');
            otherStep.subSteps = []; 
          }
        }
        if (this.tabName !== 'Assets') {           
          const assetResult = this.steps.some(item => item.name.includes("Assets"));
          if (assetResult) {
            otherStep = this.steps.find(step => step.name === 'Assets');
            otherStep.subSteps = [];
          }
        }
        if (this.tabName !== 'Debts') {            
          const debtsResult = this.steps.some(item => item.name.includes("Debts"));
          if (debtsResult) {
            otherStep = this.steps.find(step => step.name === 'Debts');
            otherStep.subSteps = [];
          }
        }
        if (this.tabName !== 'Income') {                 
        const incomeResult = this.steps.some(item => item.name.includes("Income"));
          if (incomeResult) {
            otherStep = this.steps.find(step => step.name === 'Income');
            otherStep.subSteps = [];
          }
        }
        if (this.tabName !== 'Expenses') {          
          const expenseResult = this.steps.some(item => item.name.includes("Expenses"));
          if (expenseResult) {
            otherStep = this.steps.find(step => step.name === 'Expenses');
            otherStep.subSteps = [];
          }
        }
    } catch(error)  {
      createFutureErrorRecord( {exceptionMessage: error.message ?? error.body.message, stackTrace: error.stack ?? error.body.stackTrace, lineNum: 0, errortype: 'Javascript', procname: 'virtualAccountCreater.removeOtherSubSteps'}) ;
      console.error('Exception thrown:  ', error, 'stack trace:  ', error.stack);
    };        
  }
  addingSubTab (){    
    try {
      let vitalStep;
      let opposingPartyStep;
      let childrenStep;
      let assetStep;
      let debtStep;
      let incomeStep;
      let expenseStep;
      if (this.tabName === 'Vitals') {      
        this.isAddingChild = false;
        const vitalResult = this.steps.some(item => item.name.includes("Vitals"));
        if (vitalResult) {
            vitalStep = this.steps.find(step => step.name === 'Vitals');
            if (vitalStep) {
              vitalStep.subSteps = this.vitalSubTab;  //basically, the subSteps are populated here and cleared on all the other menu items 
            }
        }
        this.removeOtherSubSteps();
      } else if (this.tabName === 'Opposing Party') {
        this.isAddingChild = false;

        const opposingResult = this.steps.some(item => item.name.includes("Opposing Party"));
        if (opposingResult) {
            opposingPartyStep = this.steps.find(step => step.name === 'Opposing Party');
            if (opposingPartyStep) {
              opposingPartyStep.subSteps = this.opposingPartySubTab;
            }
        }
        this.removeOtherSubSteps();      
      } else if (this.tabName === 'Children' && !this.isAddingChild) {
        const childResult = this.steps.some(item => item.name.includes("Children"));
        if (childResult) {
          childrenStep = this.steps.find(step => step.name === 'Children');
          if (childrenStep) {
            childrenStep.subSteps = this.childrenSubTab;
          }
        }
        this.currentSubStep = 1;
        this.removeOtherSubSteps();           
      } else if (this.tabName === 'Assets') {
        this.isAddingChild = false;
        const assetResult = this.steps.some(item => item.name.includes("Assets"));
        if (assetResult) {
          assetStep = this.steps.find(step => step.name === 'Assets');
          if (assetStep) {
            assetStep.subSteps = this.assetSubTab;
          }
        }
        this.removeOtherSubSteps();  
      } else if (this.tabName === 'Debts') {
        this.isAddingChild = false;
 
        const debtsResult = this.steps.some(item => item.name.includes("Debts"));
        if (debtsResult) {
          debtStep = this.steps.find(step => step.name === 'Debts');
          if (debtStep) {
            debtStep.subSteps = this.debtsSubTab;
          }
        }
        this.removeOtherSubSteps(); 
      } else if (this.tabName === 'Income') {
        this.isAddingChild = false;
        const incomeResult = this.steps.some(item => item.name.includes("Income"));
        if (incomeResult) {
          incomeStep = this.steps.find(step => step.name === 'Income');
          if (incomeStep) {
            incomeStep.subSteps = this.incomeSubTab;
            if (this.sefEmployee) {
              incomeStep.subSteps = this.selfEmpSectionData;
            }
          }
        }
        this.removeOtherSubSteps();         
      } else if (this.tabName === 'Expenses') {
        this.isAddingChild = false;
        const expenseResult = this.steps.some(item => item.name.includes("Expenses"));
        if (expenseResult) {
          expenseStep = this.steps.find(step => step.name === 'Expenses');
          if (expenseStep) {
            expenseStep.subSteps = this.expensesSubTab;
          }
        }
        this.removeOtherSubSteps();         
      } else if (this.tabName === 'Additional Uploads') {  //Additional Uploads has no sub steps/sub menus
        this.isAddingChild = false;
        this.removeOtherSubSteps();         
      } 
        
    } catch(error)  {
      createFutureErrorRecord( {exceptionMessage: error.message ?? error.body.message, stackTrace: error.stack ?? error.body.stackTrace, lineNum: 0, errortype: 'Javascript', procname: 'virtualAccountCreater.addingSubTab'}) ;
      console.error('Exception thrown:  ', error, 'stack trace:  ', error.stack);
    };
  }
  showToast(title, message, variant) {
    this.dispatchEvent(new ShowToastEvent({ title, message, variant }));
  }
  handleLogout() {
    this[NavigationMixin.Navigate]({
        type: 'comm__loginPage',
        attributes: {
          actionName: 'logout'
        }
    });
  }
  closeMatterPopup() {
    this.openMatterPopup = false;
  }
  handleStart (event) { //called from the select a matter modal
    getMatterDetailsForSelectedPortalUser({matterId : event.currentTarget.dataset.id}).then(result=>{
      this.ShowClientInterview = true;
      this.fillMatterData(result);
      updateMatterDateTime({matter : this.matterData})
      this.manageCIFormStatus();      
      this.closeMatterPopup();
      this.displayVitalsSubChildren();  //first menu entry is always open the Vitals sub menu to make it obvious that there's more to complete
    })
    .catch(error => {
      createFutureErrorRecord( {exceptionMessage: error.message ?? error.body.message, stackTrace: error.stack ?? error.body.stackTrace, lineNum: 0, errortype: 'Javascript', procname: 'virtualAccountCreater.handleStart'}) ;
      console.error('Exception thrown:  ', error, 'stack trace:  ', error.stack) 
    });
  }

  renderedCallback() {
    if (this.isCSSLoaded) return;
    this.isCSSLoaded = true;
    loadStyle(this, customCSS).then(() => {})
    .catch(error => {
      createFutureErrorRecord( {exceptionMessage: error.message ?? error.body.message, stackTrace: error.stack ?? error.body.stackTrace, lineNum: 0, errortype: 'Javascript', procname: 'virtualAccountCreater.renderedCallback'}) ;
      console.error('Exception thrown:  ', error, 'stack trace:  ', error.stack);  
      this.showToast('Error', 'Error occured While Loading CSS.', 'error');                
    });
  }
  handleIsEditing(event) { // to detect if the user has edited a field in on grandchild form
      this.isEditing=event.detail;
      console.log('isEditing');

      if (!this.isEditing) {
        this.menuClickWhenEditing = false;
      }
  }  
  
  handleCurrentSelfEmployee (event) {
    let incomeStep = this.steps.find(step => step.name === 'Income');
    if (event.detail) {
        if (incomeStep) {
          incomeStep.subSteps = this.selfEmpSectionData;
          this.sefEmployee = true;
        }
    } else {
      if (incomeStep) {
        incomeStep.subSteps = this.incomeSubTab;
        this.sefEmployee = false;
      }
    }
  }
// --- Chatbot State ---
  threadId;
  userMessage = '';
  isThinking = false;

  // --- Input change handler ---
  handleInput(event) {
    this.userMessage = event.target.value;
  }

  handleKeyDown(event) {
    if (event.key === 'Enter') {
      event.preventDefault();
      this.handleSendMessage();
    }
  }

  // --- Handle Send Button ---
  handleSendMessage() {
    if (this.isThinking) return;

    const trimmed = this.userMessage.trim();
    if (!trimmed) return;

    this.appendMessage(trimmed, 'user');
    const messageToSend = trimmed;
    this.userMessage = '';

    this.isThinking = true;
    const thinkingId = this.appendThinkingIndicator();

    const processRun = (runResult) => {
      const data = JSON.parse(runResult);
      this.pollStatus(this.threadId, data.id, thinkingId);
    };

    if (!this.threadId) {
      createThread()
        .then(result => {
          const data = JSON.parse(result);
          this.threadId = data.id;

          return sendMessageAndRun({ threadId: this.threadId, userMessage: messageToSend });
        })
        .then(processRun)
        .catch(error => {
          this.removeThinkingIndicator(thinkingId);
          this.isThinking = false;
          createFutureErrorRecord( {exceptionMessage: error.message ?? error.body.message, stackTrace: error.stack ?? error.body.stackTrace, lineNum: 0, errortype: 'Javascript', procname: 'virtualAccountCreater.createThread'}) ;
          console.error('Exception thrown:  ', error, 'stack trace:  ', error.stack);            
        });
    } else {
      sendMessageAndRun({ threadId: this.threadId, userMessage: messageToSend })
        .then(processRun)
        .catch(error => {
          this.removeThinkingIndicator(thinkingId);
          this.isThinking = false;
          createFutureErrorRecord( {exceptionMessage: error.message ?? error.body.message, stackTrace: error.stack ?? error.body.stackTrace, lineNum: 0, errortype: 'Javascript', procname: 'virtualAccountCreater.sendMessageAndRun'}) ;
          console.error('Exception thrown:  ', error, 'stack trace:  ', error.stack);              
        });
    }
  }

  // --- Append message to DOM ---
  appendMessage(text, sender, isHtml = false) {
    const container = this.template.querySelector('.messages-container');
    const scrollWrapper = this.template.querySelector('.chat-box');
 
    if (container) {
      const el = document.createElement('div');
      el.classList.add('message', sender);
      el.innerHTML = isHtml ? text : '';
      if (!isHtml) el.textContent = text;
      container.appendChild(el);
    // Scroll to bottom
      if (scrollWrapper) {
        scrollWrapper.scrollTop = scrollWrapper.scrollHeight;
      }
   } else {
     console.error('.messages-container not found');
   }
 }
  // --- Append thinking indicator ---
  appendThinkingIndicator() {
    const container = this.template.querySelector('.messages-container');
    const el = document.createElement('div');
    el.classList.add('message', 'bot', 'thinking');
    el.innerHTML = '<em>Thinking<span class="dots">...</span></em>';
    const id = `thinking-${Date.now()}`;
    el.id = id;
    container.appendChild(el);
    container.scrollTop = container.scrollHeight;
    // Animate dots
    const dots = el.querySelector('.dots');
    let dotCount = 3;
    const interval = setInterval(() => {
      dots.textContent = '.'.repeat(dotCount);
      dotCount = (dotCount % 6) + 1;
    }, 500);

    el.dataset.intervalId = interval;
    return id;
  }
  // --- Remove thinking indicator ---
  removeThinkingIndicator(id) {
    const el = this.template.querySelector(`#${id}`);
    if (el) {
      const intervalId = el.dataset.intervalId;
      if (intervalId) clearInterval(parseInt(intervalId));
      el.remove();
    }
  }
  // --- Poll run status ---
  pollStatus(threadId, runId, thinkingId) {
    pollRunStatus({ threadId, runId })
      .then(result => {
        const data = JSON.parse(result);
        const status = data.status;

        if (status === 'completed') {
          this.fetchAssistantReply(threadId, thinkingId);
        } else if (['queued', 'in_progress'].includes(status)) {
          setTimeout(() => this.pollStatus(threadId, runId, thinkingId), 1000);
        } else {
          this.removeThinkingIndicator(thinkingId);
          this.isThinking = false;
          console.warn('Run failed or cancelled:', status);
        }
      })
      .catch(error => {
        this.removeThinkingIndicator(thinkingId);
        this.isThinking = false;
        createFutureErrorRecord( {exceptionMessage: error.message ?? error.body.message, stackTrace: error.stack ?? error.body.stackTrace, lineNum: 0, errortype: 'Javascript', procname: 'virtualAccountCreater.pollStatus'}) ;
        console.error('Exception thrown:  ', error, 'stack trace:  ', error.stack);           
      });
  }
  // --- Get assistant message from thread ---
  fetchAssistantReply(threadId, thinkingId) {
    getAssistantMessages({ threadId })
      .then(result => {
        const data = JSON.parse(result);
        const assistantMessages = data.data.filter(msg => msg.role === 'assistant');
        if (assistantMessages.length > 0) {
          const lastMessage = assistantMessages[0];
          let messageText = '';
          for (const part of lastMessage.content) {
            if (part.type === 'text') {
              messageText += part.text.value;
            }
          }
          this.removeThinkingIndicator(thinkingId);
          this.isThinking = false;
          this.appendMessage(this.formatBotReply(messageText), 'bot', true);
        } else {
          this.removeThinkingIndicator(thinkingId);
          this.isThinking = false;
        }
      })
      .catch(error => {
        this.removeThinkingIndicator(thinkingId);
        this.isThinking = false;
        createFutureErrorRecord( {exceptionMessage: error.message ?? error.body.message, stackTrace: error.stack ?? error.body.stackTrace, lineNum: 0, errortype: 'Javascript', procname: 'virtualAccountCreater.getAssistanMessages'}) ;
        console.error('Exception thrown:  ', error, 'stack trace:  ', error.stack);            
      });
  }
  // --- Format bot reply with markdown-like styling ---
  formatBotReply(reply) {
    let formatted = reply
      .replace(/\*\*(.+?)\*\*/g, '<strong>$1</strong>')
      .replace(/\n/g, '<br>');

    const listItemRegex = /<br>(\s*[-*•]\s+|\s*\d+\.\s+)(.+?)(?=<br>|$)/g;
    formatted = formatted.replace(listItemRegex, (match, bullet, content) => {
      return '<br><li>' + content + '</li>';
    });
    formatted = formatted.replace(/(<li>.+?<\/li>)(\s*<br>\s*<li>.+?<\/li>)*/g, '<ul>$&</ul>');
    return formatted;
  }

  // ── userDashboard child event handlers ───────────────────

  // Mirrors handleStart() / getDetailsSingleMatter(): fetch the selected matter,
  // run fillMatterData → manageCIFormStatus → displayVitalsSubChildren, then
  // route based on stepType.
  handleContinueStep(event) {
    const { matterId, stepType } = event.detail || {};
    this.showUserDashboard = false;
    this.canReturnToDashboard = true;

    if (stepType === 'attorneyTransition') {
      // Find the matter in the cached list so we can set the retaining flag
      const matter = (this.allMatterCases || []).find(m => m.Id === matterId);
      if (matter && matter.Primary_Attorney__r) {
        this.retainingClients = matter.Primary_Attorney__r.Retaining_Clients__c === true ? 'true' : 'false';
      }
      this.recordIdToPass = matterId;
      this.attorneyTransition = true;
      return;
    }

    if (stepType === 'payInvoice') {
      this.handlePayNow(event);
      return;
    }

    if (stepType === 'feeAgreement') {
      // Generate / continue the fee agreement (mirrors the connectedCallback
      // cascade ~lines 353–355). showUserDashboard / canReturnToDashboard are
      // already set above.
      this.IsFeeAgreement = true;
      this.ShowFeeAgreementLanding = true;
      return;
    }

    // Default: clientInterview (and any unrecognised step) → route into CI
    if (!matterId) {
      // No matter selected; nothing to route to. Re-show dashboard.
      this.showUserDashboard = true;
      this.canReturnToDashboard = false;
      return;
    }
    getMatterDetailsForSelectedPortalUser({ matterId })
      .then(result => {
        this.ShowClientInterview = true;
        this.fillMatterData(result);
        updateMatterDateTime({ matter: this.matterData });
        this.manageCIFormStatus();
        this.displayVitalsSubChildren();
      })
      .catch(error => {
        createFutureErrorRecord({
          exceptionMessage: error.message ?? error.body?.message,
          stackTrace: error.stack ?? error.body?.stackTrace,
          lineNum: 0,
          errortype: 'Javascript',
          procname: 'virtualAccountCreater.handleContinueStep'
        });
        console.error('handleContinueStep failed:', error);
        // Fail soft — show dashboard again so user can retry
        this.showUserDashboard = true;
        this.canReturnToDashboard = false;
      });
  }

  handlePayNow(event) {
    this.showUserDashboard = false;
    this.IsFeeAgreement = true;
    this.ShowPaymentLink = true;
    this.canReturnToDashboard = true;
  }

  // ── Dashboard → sub-page routing (Phase 2 items C, E) ─────────────
  handleViewAllFaqs() {
    this.showUserDashboard = false;
    this.showFaq = true;
    this.canReturnToDashboard = false; // sub-pages have their own Back link
  }

  handleViewAllUpdates() {
    this.showUserDashboard = false;
    this.showAllUpdates = true;
    this.canReturnToDashboard = false;
  }

  // Clears every sub-view flag. Single source of truth for "hide everything"
  // so callers can't drift out of sync (the SimpleStart sub-step flags below
  // were previously missed by returnToDashboard, leaving stale views).
  resetAllViews() {
    this.showFaq = false;
    this.showAllUpdates = false;
    this.IsSimpleStart = false;
    this.IsFeeAgreement = false;
    this.ShowSimpleStartLandingPage = false;
    this.ShowSimpleStartApplication = false;
    this.ShowSimpleStartAddress = false;
    this.ShowConsent = false;
    this.ShowWaiting = false;
    this.ShowRetainerDecision = false;
    this.ShowFeeAgreementLanding = false;
    this.ShowFeeAgreement = false;
    this.ShowPaymentLink = false;
    this.ShowThankYouPage = false;
    this.ShowClientInterview = false;
    this.attorneyTransition = false;
  }

  // Fired by faqPage / viewAllUpdates / etc. when their Back-to-Dashboard
  // link is clicked. Also used by the global "← Back to Dashboard" link in
  // the header for users routed into CI / FA / Payment.
  returnToDashboard() {
    this.resetAllViews();
    this.canReturnToDashboard = false;
    this.showUserDashboard = true;
  }

  // Toast for successful Contact Finance submission (event from dashboard).
  handleFinanceSent() {
    this.showToast(
      'Message sent',
      'The finance team will get back to you within one business day.',
      'success'
    );
  }
}