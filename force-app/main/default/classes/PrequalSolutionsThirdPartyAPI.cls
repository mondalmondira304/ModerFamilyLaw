public without sharing class PrequalSolutionsThirdPartyAPI {
    // Static map to hold state name to code conversions
    private static final Map<String, String> STATE_CODES = new Map<String, String>{
        'alabama' => 'AL', 'alaska' => 'AK', 'arizona' => 'AZ', 'arkansas' => 'AR',
        'california' => 'CA', 'colorado' => 'CO', 'connecticut' => 'CT', 'delaware' => 'DE',
        'florida' => 'FL', 'georgia' => 'GA', 'hawaii' => 'HI', 'idaho' => 'ID',
        'illinois' => 'IL', 'indiana' => 'IN', 'iowa' => 'IA', 'kansas' => 'KS',
        'kentucky' => 'KY', 'louisiana' => 'LA', 'maine' => 'ME', 'maryland' => 'MD',
        'massachusetts' => 'MA', 'michigan' => 'MI', 'minnesota' => 'MN', 'mississippi' => 'MS',
        'missouri' => 'MO', 'montana' => 'MT', 'nebraska' => 'NE', 'nevada' => 'NV',
        'new hampshire' => 'NH', 'new jersey' => 'NJ', 'new mexico' => 'NM', 'new york' => 'NY',
        'north carolina' => 'NC', 'north dakota' => 'ND', 'ohio' => 'OH', 'oklahoma' => 'OK',
        'oregon' => 'OR', 'pennsylvania' => 'PA', 'rhode island' => 'RI', 'south carolina' => 'SC',
        'south dakota' => 'SD', 'tennessee' => 'TN', 'texas' => 'TX', 'utah' => 'UT',
        'vermont' => 'VT', 'virginia' => 'VA', 'washington' => 'WA', 'west virginia' => 'WV',
        'wisconsin' => 'WI', 'wyoming' => 'WY'
    };

    /*** TEST-ONLY OVERRIDES  ***/
    @TestVisible private static String tvNamedCredential; 
    @TestVisible private static String tvScenario;        

    @TestVisible
    private static Prequal_Integration_Config__mdt getConfig() {
        if (Test.isRunningTest() && (!String.isBlank(tvNamedCredential) || !String.isBlank(tvScenario))) {
            Prequal_Integration_Config__mdt testCfg = new Prequal_Integration_Config__mdt();
            testCfg.Named_Credential__c = tvNamedCredential;
            testCfg.Scenario__c         = tvScenario;

            if (!String.isBlank(testCfg.Named_Credential__c) && !String.isBlank(testCfg.Scenario__c)) {
                return testCfg;
            }

            Prequal_Integration_Config__mdt realCfg = Prequal_Integration_Config__mdt.getInstance('Default');
            if (realCfg == null) {
                throw new AuraHandledException('Prequal Integration Config (Default) not found in CMDT.');
            }
            if (String.isBlank(testCfg.Scenario__c))         testCfg.Scenario__c         = realCfg.Scenario__c;
            if (String.isBlank(testCfg.Named_Credential__c)) testCfg.Named_Credential__c = realCfg.Named_Credential__c;

            if (String.isBlank(testCfg.Scenario__c)) {
                throw new AuraHandledException('Scenario__c is not configured in Prequal Integration Config CMDT.');
            }
            if (String.isBlank(testCfg.Named_Credential__c)) {
                throw new AuraHandledException('Named_Credential__c is not configured in Prequal Integration Config CMDT.');
            }
            return testCfg;
        }

        Prequal_Integration_Config__mdt cfg = Prequal_Integration_Config__mdt.getInstance('Default');
        if (cfg == null) {
            throw new AuraHandledException('Prequal Integration Config (Default) not found in CMDT.');
        }
        if (String.isBlank(cfg.Scenario__c)) {
            throw new AuraHandledException('Scenario__c is not configured in Prequal Integration Config CMDT.');
        }
        if (String.isBlank(cfg.Named_Credential__c)) {
            throw new AuraHandledException('Named_Credential__c is not configured in Prequal Integration Config CMDT.');
        }
        return cfg;
    }

    /**
     * @description Queueable job for processing API integration asynchronously
     */
    public without sharing class APIIntegrationJob implements Queueable, Database.AllowsCallouts {
        
        private Id thirdPartyId;
        private Id parentAccountId;
        
        public APIIntegrationJob(Id thirdPartyId, Id parentAccountId) {
            this.thirdPartyId = thirdPartyId;
            this.parentAccountId = parentAccountId;
        }

        public void execute(QueueableContext context) {
            try {
                System.debug(LoggingLevel.INFO, '==> Running job for Third Party: ' + thirdPartyId + ', Parent Account: ' + parentAccountId);

                Prequal_Integration_Config__mdt cfg = getConfig();
                String scenario = cfg.Scenario__c;

                System.debug(LoggingLevel.INFO, 'Prequal scenario in use: ' + scenario);
                System.debug(LoggingLevel.INFO, 'Using Named Credential: ' + cfg.Named_Credential__c);

                Account thirdParty = getThirdPartyAccount();
                Account parent = getParentAccount();

                Map<String, Object> requestPayload = buildRequestPayload(thirdParty, scenario);
                HttpResponse response = makeApiCallout(requestPayload, cfg.Named_Credential__c);

                Integer sc = response.getStatusCode();
                if (sc == 200) {
                    processSuccessfulResponse(response, thirdParty, parent);
                } else if (sc == 400) {
                    processValidationErrors(response, parent); // << NEW
                } else {
                    handleFailedResponse(response);
                }
            } catch (Exception e) {
                System.debug(LoggingLevel.ERROR, 'Error in APIIntegrationJob: ' + e.getMessage());
                System.debug(LoggingLevel.ERROR, 'Stack trace: ' + e.getStackTraceString());
            }
        }
        
        // Handle 400 validation responses by saving API messages to the parent Account
        private void processValidationErrors(HttpResponse response, Account parent) {
            try {
                Map<String, Object> root = (Map<String, Object>) JSON.deserializeUntyped(response.getBody());
                Map<String, Object> api  = (Map<String, Object>) root.get('api');
                Map<String, Object> resp = api == null ? null : (Map<String, Object>) api.get('response');
                Map<String, Object> errs = resp == null ? null : (Map<String, Object>) resp.get('errors');
                Map<String, Object> msgs = errs == null ? null : (Map<String, Object>) errs.get('messages');

                List<String> flatMsgs = new List<String>();
                if (msgs != null) {
                    for (String fieldName : msgs.keySet()) {
                        List<Object> arr = (List<Object>) msgs.get(fieldName);
                        if (arr != null) {
                            for (Object o : arr) {
                                if (o != null) {
                                    flatMsgs.add(fieldName + ': ' + String.valueOf(o));
                                }
                            }
                        }
                    }
                }

                String allMsgs = flatMsgs.isEmpty()
                    ? 'Validation error (400) with no messages returned.'
                    : String.join(flatMsgs, '\n');

                if (allMsgs.length() > 255) allMsgs = allMsgs.substring(0, 255);

                Account accUpdate = new Account(
                    Id = parent.Id,
                    Credit_Check_Complete__c = false,
                    Credit_Decision__c        = 'Full Retainer',
                    Credit_Report_Link__c     = 'Failed-400',
                    Quoted_Retainer_Amount__c = parent.Quoted_Retainer__c,
                    Credit_Message__c         = allMsgs
                );
                update accUpdate;

                System.debug(LoggingLevel.WARN, 'Saved API validation errors to Account ' + parent.Id + ': ' + allMsgs);
            } catch (Exception ex) {
                System.debug(LoggingLevel.ERROR, 'Failed to process 400 validation errors: ' + ex.getMessage());
                System.debug(LoggingLevel.ERROR, response.getBody());
            }
        }

        private Account getThirdPartyAccount() {
            return [
                SELECT Id, FirstName, LastName, PersonMailingStreet, PersonMailingCity, State_A__c,
                       PersonMailingPostalCode, Birthdate__c, PersonMobilePhone, PersonEmail,
                       Annual_household_income__c, Social_Security_Number__c
                FROM Account 
                WHERE Id = :thirdPartyId
                LIMIT 1
            ];
        }

        private Account getParentAccount() {
            return [
                SELECT Id, Quoted_Retainer__c 
                FROM Account 
                WHERE Id = :parentAccountId 
                LIMIT 1
            ];
        }
        
        private String getStateCode(String fullStateName) {
            if (String.isBlank(fullStateName)) {
                return fullStateName;
            }
            String stateCode = STATE_CODES.get(fullStateName.toLowerCase());
            return (stateCode != null) ? stateCode : fullStateName;
        }

        private Map<String, Object> buildRequestPayload(Account thirdParty, String scenario) {
            Map<String, Object> applicant = new Map<String, Object>{
                'firstname' => thirdParty.FirstName,
                'middlename' => '',
                'lastname' => thirdParty.LastName,
                'address_1' => thirdParty.PersonMailingStreet,
                'address_2' => '',
                'city' => thirdParty.PersonMailingCity,
                'state' => getStateCode(thirdParty.State_A__c),
                'zip' => thirdParty.PersonMailingPostalCode,
                'dob' => formatBirthdate(thirdParty.Birthdate__c),
                'ssn' => thirdParty.Social_Security_Number__c,
                'phone' => thirdParty.PersonMobilePhone,
                'email' => thirdParty.PersonEmail,
                'income' => thirdParty.Annual_household_income__c != null ? String.valueOf(thirdParty.Annual_household_income__c) : null
            };

            return new Map<String, Object>{
                'applicant' => applicant,
                'scenario' => scenario
            };
        }

        private String formatBirthdate(Date birthdate) {
            if (birthdate == null) {
                return '';
            }
            return DateTime.newInstance(birthdate.year(), birthdate.month(), birthdate.day()).format('yyyy-MM-dd');
        }

        private HttpResponse makeApiCallout(Map<String, Object> requestPayload, String namedCredential) {
            HttpRequest req = new HttpRequest();
            req.setEndpoint('callout:' + namedCredential);
            req.setMethod('POST');
            req.setHeader('Content-Type', 'application/json');
            req.setBody(JSON.serialize(requestPayload));

            Http http = new Http();
            return http.send(req);
        }

        private void processSuccessfulResponse(HttpResponse response, Account thirdParty, Account parent) {
            ApiResponseWrapper resp = (ApiResponseWrapper) JSON.deserialize(response.getBody(), ApiResponseWrapper.class);

            if (isValidResponse(resp)) {
                IndividualReport report = resp.api.response.data.reports.individual[0];
                updateAccountWithCreditDecision(report, thirdParty, parent);
            }
        }

        private Boolean isValidResponse(ApiResponseWrapper resp) {
            return resp != null && 
                   resp.api != null && 
                   resp.api.response != null && 
                   resp.api.response.data != null && 
                   resp.api.response.data.reports != null && 
                   !resp.api.response.data.reports.individual.isEmpty();
        }

        private void updateAccountWithCreditDecision(IndividualReport report, Account thirdParty, Account parent) {
            Account accUpdate = new Account(Id = parent.Id);
            accUpdate.Third_Party__c = thirdParty.Id;
            accUpdate.Annual_household_income__c = thirdParty.Annual_household_income__c;
            accUpdate.Credit_Report_Link__c = report.temporary_shareable_link;

            Boolean creditFrozen = isCreditFrozen(report);
            Boolean noFileReturn = isNoFileReturn(report); 
            Boolean hasPass      = hasPassingOffer(report);

            CreditDecisionData decisionData = new CreditDecisionData();
            decisionData.creditFrozen   = creditFrozen;
            decisionData.noFileReturn   = noFileReturn; 
            decisionData.notQualified   = (!creditFrozen && !noFileReturn && !hasPass);
            decisionData.quotedRetainer = parent.Quoted_Retainer__c;
            decisionData.chosenOffer    = (!creditFrozen && !noFileReturn) ? determineChosenOffer(report) : null;

            setCreditDecisionFields(accUpdate, decisionData);

            update accUpdate;
        }

        private String determineChosenOffer(IndividualReport report) {
            List<Decisioning> passingOffers = getPassingOffers(report);
            List<String> offerPriority = new List<String>{
                'Gold - 0% Retainer', 'Silver - 50% Retainer', 'Bronze - 80% Retainer'
            };

            for (String offerName : offerPriority) {
                for (Decisioning d : passingOffers) {
                    if (d.criteria_set_name != null && d.criteria_set_name.trim().toLowerCase() == offerName.toLowerCase()) {
                        return offerName;
                    }
                }
            }
            return null;
        }

        private List<Decisioning> getPassingOffers(IndividualReport report) {
            List<Decisioning> passingOffers = new List<Decisioning>();
            if (report.decisioning != null) {
                for (Decisioning d : report.decisioning) {
                    if (d.result != null && d.result.toLowerCase() == 'pass') {
                        passingOffers.add(d);
                    }
                }
            }
            return passingOffers;
        }
        
        private Boolean hasPassingOffer(IndividualReport report) {
    if (report == null || report.decisioning == null) return false;
    for (Decisioning d : report.decisioning) {
        if (d != null && d.result != null && d.result.toLowerCase() == 'pass') return true;
    }
    return false;
}


        // Expanded: considers indicators OR CREDIT_FILE.ResultStatusType='NoFileReturnedCreditFreeze'
        private Boolean isCreditFrozen(IndividualReport report) {
            if (report == null || report.details == null || report.details.normalized == null) return false;

            CreditFrozenStatus frozen = report.details.normalized.CREDIT_FROZEN_STATUS;
            if (frozen != null) {
                if ((frozen.EquifaxIndicator == 'true') ||
                    (frozen.ExperianIndicator == 'true') ||
                    (frozen.TransUnionIndicator == 'true')) {
                    return true;
                }
            }
            if (report.details.normalized.CREDIT_FILE != null &&
                report.details.normalized.CREDIT_FILE.ResultStatusType != null &&
                report.details.normalized.CREDIT_FILE.ResultStatusType.equalsIgnoreCase('NoFileReturnedCreditFreeze')) {
                return true;
            }
            return false;
        }

        // "No File Returned" detector  (tolerant of variants like NoFileReturnedNoHit)
        private Boolean isNoFileReturn(IndividualReport report) {
            if (report == null) return false;

            // A) top-level
            if (report.result_status_type != null &&
                report.result_status_type.toLowerCase().startsWith('nofilereturned')) {
                return true;
            }
            // B) normalized CREDIT_FILE
            if (report.details != null && report.details.normalized != null &&
                report.details.normalized.CREDIT_FILE != null &&
                report.details.normalized.CREDIT_FILE.ResultStatusType != null) {

                String rst = report.details.normalized.CREDIT_FILE.ResultStatusType.toLowerCase();
                if (rst.contains('nofilereturned') && !rst.contains('creditfreeze')) {
                    return true;
                }
            }
            return false;
        }

        private void setCreditDecisionFields(Account accUpdate, CreditDecisionData decisionData) {
            Decimal multiplier = getRetainerMultiplier(decisionData.chosenOffer);

            if (decisionData.chosenOffer != null) {
                accUpdate.Credit_Decision__c = decisionData.chosenOffer;
                accUpdate.Credit_Check_Complete__c = true;
                accUpdate.Quoted_Retainer_Amount__c = decisionData.quotedRetainer != null ? decisionData.quotedRetainer * multiplier : null;

            } else if (decisionData.creditFrozen) {
                accUpdate.Credit_Decision__c = 'Credit Frozen';
                accUpdate.Credit_Check_Complete__c = false;
                accUpdate.Credit_Message__c  = 'The credit report was found, but is frozen, and therefore cannot be accessed.';               
                accUpdate.Quoted_Retainer_Amount__c = decisionData.quotedRetainer;

            } else if (decisionData.noFileReturn) { 
                accUpdate.Credit_Decision__c = 'Full Retainer';
                accUpdate.Credit_Check_Complete__c = true;
                accUpdate.Credit_Message__c  = 'No credit file was returned (No Hit).';
                accUpdate.Quoted_Retainer_Amount__c = decisionData.quotedRetainer;
                
                } else if (decisionData.notQualified) {                   
    accUpdate.Credit_Decision__c        = 'Full Retainer';
    accUpdate.Credit_Check_Complete__c  = true;
    accUpdate.Credit_Message__c         = 'Not Qualified by criteria.';  
    accUpdate.Quoted_Retainer_Amount__c = decisionData.quotedRetainer;

            } else {
                
                accUpdate.Credit_Decision__c = 'Full Retainer';
                accUpdate.Credit_Check_Complete__c = true;
                accUpdate.Credit_Message__c  = 'Unknown Error'; 
                accUpdate.Quoted_Retainer_Amount__c = decisionData.quotedRetainer;
            }
        }

        private Decimal getRetainerMultiplier(String chosenOffer) {
            if (chosenOffer == 'Gold - 0% Retainer') {
                return 0;
            } else if (chosenOffer == 'Silver - 50% Retainer') {
                return 0.5;
            } else if (chosenOffer == 'Bronze - 80% Retainer') {
                return 0.8;
            }
            return 1;
        }

        private void handleFailedResponse(HttpResponse response) {
            System.debug(LoggingLevel.ERROR, 'Callout failed with status: ' + response.getStatusCode());
            System.debug(LoggingLevel.ERROR, 'Response body: ' + response.getBody());
        }
    }

    private class CreditDecisionData {
        public String chosenOffer;
        public Boolean creditFrozen;
        public Boolean noFileReturn;
        public Boolean notQualified;
        public Decimal quotedRetainer;
    }

    public class ApiResponseWrapper { public ApiSection api; }
    public class ApiSection { public String reference_id; public ApiRequest request; public ApiResponse response; }
    public class ApiRequest { public String product; public String server; public String endpoint; public String api_datetime; public String user; public String ip; }
    public class ApiResponse { public Integer code; public ResponseData data; }
    public class ResponseData { public Applicant applicant; public Reports reports; }
    public class Applicant { public String id; public String created_at; public String firstname; public String middlename; public String lastname; public String phone; public String email; public String tracking_id; public String address_1; public String address_2; public String city; public String state; public String zip; public String dob; public String ssn; public String income; public String custom; }
    public class Reports { public List<Object> merged; public List<IndividualReport> individual; }
    public class IndividualReport { public String id; public String created_at; public String bureau; public String processing; public String result_status_type; public String temporary_shareable_link; public List<Decisioning> decisioning; public Details details; }
    public class Decisioning { public String criteria_id; public String criteria_set_name; public String result; public List<Offer> offers; }
    public class Offer { public Integer id; public String name; public String tracking_id; public String url; }
    public class Details { public Normalized normalized; }

    public class Normalized { public CreditFrozenStatus CREDIT_FROZEN_STATUS; public CreditFile CREDIT_FILE; }
    public class CreditFrozenStatus { public String EquifaxIndicator; public String ExperianIndicator; public String TransUnionIndicator; }
    public class CreditFile { public String CreditRepositorySourceType; public String InfileDate; public String ResultStatusType; }
}