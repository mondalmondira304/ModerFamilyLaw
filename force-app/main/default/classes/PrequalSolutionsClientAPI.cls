/*
ERROR LOG QUICK REFERENCE (ErrorLog__c only)
- CERT / TLS / TIMEOUT: http.send(req) throws exception → ERROR, no Account update
- HTTP != 200 && != 400: Prequal returns 401/403/500/etc → ERROR, no Account update
- HTTP 200 INVALID BODY: Missing reports.individual → ERROR, no Account update
- HTTP 400 VALIDATION: Prequal validation failure → WARN, Account set to Full Retainer
- APEX EXCEPTION: Any runtime/JSON/DML error → ERROR, no Account update
- @SANDERS 01-11-2026
*/


public without sharing class PrequalSolutionsClientAPI {

    private static final String INTEGRATION_NAME = 'PrequalSolutions';

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

    private static String getStateCode(String fullStateName) {
        if (String.isBlank(fullStateName)) {
            return fullStateName;
        }
        String stateCode = STATE_CODES.get(fullStateName.toLowerCase());
        return (stateCode != null) ? stateCode : fullStateName;
    }

    
        /**
     * @description
     *  Normalizes a phone string into exactly 10 digits (US format) for API transmission.
     *  - Removes all non-digit characters
     *  - If >10 digits, keeps the last 10 digits 
     *  - If <10 digits, returns null
     */
    private static String normalizePhone10(String rawPhone) {
        if (String.isBlank(rawPhone)) return null;

        String digitsOnly = rawPhone.replaceAll('[^0-9]', '');
        if (String.isBlank(digitsOnly)) return null;

        if (digitsOnly.length() == 11 && digitsOnly.startsWith('1')) {
            digitsOnly = digitsOnly.substring(1);
        }

        if (digitsOnly.length() > 10) {
            digitsOnly = digitsOnly.substring(digitsOnly.length() - 10);
        }

        if (digitsOnly.length() != 10) return null;

        return digitsOnly;
    }

    /**
     * @description
     *  Chooses the best phone source, then normalizes to 10 digits.
     *  Preference: PersonMobilePhone -> Phone.
     */
    private static String getNormalizedApplicantPhone(Account acc) {
        String preferred = String.isNotBlank(acc.PersonMobilePhone) ? acc.PersonMobilePhone : acc.Phone;
        return normalizePhone10(preferred);
    }

    
    private static void logError(
        Id relatedAccountId,
        String methodName,
        String errorType,
        Integer httpStatusCode,
        String requestDetails,
        String errorMessage,
        Exception ex
    ) {
        try {
            ErrorLog__c logRec = new ErrorLog__c();
            logRec.Integration_Name__c = INTEGRATION_NAME;
            logRec.Class_Name__c       = 'PrequalSolutionsClientAPI';
            logRec.Method_Name__c      = methodName;
            logRec.ErrorType__c        = errorType;

            if (relatedAccountId != null) logRec.Related_Account__c = relatedAccountId;
            if (httpStatusCode != null)   logRec.HTTP_Status_Code__c = httpStatusCode;

            if (!String.isBlank(requestDetails)) {
                // Field is Long Text Area(32768); keep it safe.
                logRec.Request_Details__c = (requestDetails.length() > 32768)
                    ? requestDetails.substring(0, 32768)
                    : requestDetails;
            }

            if (!String.isBlank(errorMessage)) {
                // Field is Long Text Area(50000); keep it safe.
                logRec.ErrorMessage__c = (errorMessage.length() > 50000)
                    ? errorMessage.substring(0, 50000)
                    : errorMessage;
            }

            if (ex != null) {
                String st = ex.getStackTraceString();
                if (!String.isBlank(st)) {
                    logRec.ErrorStackTrace__c = (st.length() > 50000) ? st.substring(0, 50000) : st;
                }
                Integer lineNo = ex.getLineNumber();
                if (lineNo != null && lineNo > 0) logRec.ErrorLineNumber__c = lineNo;
            }

            insert logRec;
        } catch (Exception ignore) {
            // Intentionally swallow logging exceptions.
        }
    }

    /**
     * Convenience overload for simple message logging (no Exception object).
     */
    private static void logError(
        Id relatedAccountId,
        String methodName,
        String errorType,
        Integer httpStatusCode,
        String requestDetails,
        String errorMessage
    ) {
        logError(relatedAccountId, methodName, errorType, httpStatusCode, requestDetails, errorMessage, null);
    }

    private static Prequal_Integration_Config__mdt getConfig() {
        Prequal_Integration_Config__mdt cfg = Prequal_Integration_Config__mdt.getInstance('Default');
        if (cfg == null) {
            logError(null, 'getConfig', 'ERROR', null, null, 'Prequal Integration Config (Default) not found in CMDT.');
            throw new AuraHandledException('Prequal Integration Config (Default) not found in CMDT.');
        }
        if (String.isBlank(cfg.Scenario__c)) {
            logError(null, 'getConfig', 'ERROR', null, null, 'Scenario__c is not configured in Prequal Integration Config CMDT.');
            throw new AuraHandledException('Scenario__c is not configured in Prequal Integration Config CMDT.');
        }
        if (String.isBlank(cfg.Named_Credential__c)) {
            logError(null, 'getConfig', 'ERROR', null, null, 'Named_Credential__c is not configured in Prequal Integration Config CMDT.');
            throw new AuraHandledException('Named_Credential__c is not configured in Prequal Integration Config CMDT.');
        }
        return cfg;
    }

    public class APIIntegrationJob implements Queueable, Database.AllowsCallouts {
        private List<Id> accountIds;

        public APIIntegrationJob(List<Id> accountIds) {
            this.accountIds = accountIds;
        }

        public void execute(QueueableContext context) {
            try {
                Prequal_Integration_Config__mdt cfg = getConfig();
                String scenario = cfg.Scenario__c;

                List<Account> accounts = [
                    SELECT Id, FirstName, MiddleName, LastName, PersonMailingStreet, PersonMailingCity, State_A__c,
                           PersonMailingPostalCode, Birthdate__c, Phone, PersonEmail, PersonMobilePhone, Quoted_Retainer__c,
                           Responsible_Attorney__c, Responsible_Attorney_Email_A__c, Credit_Check_Submitted__c,
                           Annual_household_income__c, Social_Security_Number__c
                    FROM Account WHERE Id IN :accountIds
                ];

                List<Account> accountsToUpdate = new List<Account>();

                for (Account acc : accounts) {
                    try {
                        Map<String, Object> applicant = new Map<String, Object>{
                            'firstname' => acc.FirstName,
                            'middlename' => acc.MiddleName,
                            'lastname' => acc.LastName,
                            'address_1' => acc.PersonMailingStreet,
                            'address_2' => '',
                            'city' => acc.PersonMailingCity,
                            'state' => getStateCode(acc.State_A__c),
                            'zip' => acc.PersonMailingPostalCode,
                            'ssn' => acc.Social_Security_Number__c,
                            'phone' => getNormalizedApplicantPhone(acc),
                            'dob' => acc.Birthdate__c,
                            'email' => acc.PersonEmail,
                            'income' => acc.Annual_household_income__c != null ? String.valueOf(acc.Annual_household_income__c) : null
                        };

                        Map<String, Object> requestPayload = new Map<String, Object>{
                            'applicant' => applicant,
                            'scenario' => scenario
                        };

                        HttpRequest req = new HttpRequest();
                        req.setEndpoint('callout:' + cfg.Named_Credential__c);
                        req.setMethod('POST');
                        req.setTimeout(60000);
                        req.setHeader('Content-Type', 'application/json');
                        req.setBody(JSON.serialize(requestPayload));

                       HttpResponse res;
                        Integer code;
                        
                        try {
                            Http http = new Http();
                            res = http.send(req);      
                            code = res.getStatusCode();
                        } catch (Exception calloutEx) {
                            logError(
                                acc.Id,
                                'APIIntegrationJob.execute',
                                'ERROR',
                                null,
                                JSON.serialize(requestPayload),
                                'HTTP callout failed (certificate / TLS): ' + calloutEx.getMessage(),
                                calloutEx
                            );
                            continue;
                        }

                        // --- Response Handling ---
                        if (code == 200) {
                            ApiResponseWrapper resp =
                                (ApiResponseWrapper) JSON.deserialize(res.getBody(), ApiResponseWrapper.class);

                            if (
                                resp != null && resp.api != null && resp.api.response != null &&
                                resp.api.response.data != null && resp.api.response.data.reports != null &&
                                resp.api.response.data.reports.individual != null && !resp.api.response.data.reports.individual.isEmpty()
                            ) {
                                IndividualReport report = resp.api.response.data.reports.individual[0];
                                Account accUpdate = new Account(Id = acc.Id);

                                // 1) Report link
                                accUpdate.Credit_Report_Link__c = report.temporary_shareable_link;

                                Boolean creditFrozen = false;
                                Boolean noFileReturn = false;

                                // Freeze via indicators or CREDIT_FILE.ResultStatusType = NoFileReturnedCreditFreeze
                                if (report.details != null && report.details.normalized != null) {
                                    if (report.details.normalized.CREDIT_FROZEN_STATUS != null) {
                                        CreditFrozenStatus frozen = report.details.normalized.CREDIT_FROZEN_STATUS;
                                        if ((frozen.EquifaxIndicator == 'true') ||
                                            (frozen.ExperianIndicator == 'true') ||
                                            (frozen.TransUnionIndicator == 'true')) {
                                            creditFrozen = true;
                                        }
                                    }
                                    if (!creditFrozen && report.details.normalized.CREDIT_FILE != null &&
                                        report.details.normalized.CREDIT_FILE.ResultStatusType != null &&
                                        report.details.normalized.CREDIT_FILE.ResultStatusType.equalsIgnoreCase('NoFileReturnedCreditFreeze')) {
                                        creditFrozen = true;
                                    }
                                }

                                // No-file-return (tolerant of variants like NoFileReturnedNoHit)
                                if (!creditFrozen) {
                                    if ((report.result_status_type != null &&
                                         report.result_status_type.toLowerCase().startsWith('nofilereturned')) ||
                                        (report.details != null && report.details.normalized != null &&
                                         report.details.normalized.CREDIT_FILE != null &&
                                         report.details.normalized.CREDIT_FILE.ResultStatusType != null &&
                                         report.details.normalized.CREDIT_FILE.ResultStatusType.toLowerCase().contains('nofilereturned') &&
                                         !report.details.normalized.CREDIT_FILE.ResultStatusType.toLowerCase().contains('creditfreeze'))) {
                                        noFileReturn = true;
                                    }
                                }

                                // Decisioning evaluated ONLY when not frozen and not no-file
                                String chosenOffer = null;
                                Boolean hasPass = false;
                                if (!creditFrozen && !noFileReturn) {
                                    List<Decisioning> passingOffers = new List<Decisioning>();
                                    if (report.decisioning != null) { // guard
                                        for (Decisioning d : report.decisioning) {
                                            if (d != null && d.result != null && d.result.toLowerCase() == 'pass') {
                                                passingOffers.add(d);
                                            }
                                        }
                                    }
                                    hasPass = !passingOffers.isEmpty();
                                    List<String> offerPriority = new List<String>{
                                        'Gold - 0% Retainer', 'Silver - 50% Retainer', 'Bronze - 80% Retainer'
                                    };
                                    for (String offerName : offerPriority) {
                                        for (Decisioning d : passingOffers) {
                                            if (d.criteria_set_name != null &&
                                                d.criteria_set_name.trim().toLowerCase() == offerName.toLowerCase()) {
                                                chosenOffer = offerName;
                                                break;
                                            }
                                        }
                                        if (chosenOffer != null) break;
                                    }
                                }

                                // 4) Finalize outcome (freeze → no file → success w/ offers → fallback)
                                if (creditFrozen) {
                                    accUpdate.Credit_Decision__c = 'Credit Frozen';
                                    accUpdate.Credit_Check_Complete__c = false;
                                    accUpdate.Quoted_Retainer_Amount__c = acc.Quoted_Retainer__c;
                                    accUpdate.Credit_Message__c  =
                                        'The credit report was found, but is frozen, and therefore cannot be accessed.';
                                } else if (noFileReturn) {
                                    accUpdate.Credit_Decision__c = 'Full Retainer';
                                    accUpdate.Credit_Check_Complete__c = true;
                                    accUpdate.Quoted_Retainer_Amount__c = acc.Quoted_Retainer__c;
                                    accUpdate.Credit_Message__c  = 'No credit file was returned (No Hit).';
                                } else if (chosenOffer != null) {
                                    accUpdate.Credit_Decision__c = chosenOffer;
                                    accUpdate.Credit_Check_Complete__c = true;
                                    accUpdate.Credit_Message__c = null;

                                    Decimal multiplier = 1;
                                    if (chosenOffer == 'Gold - 0% Retainer')         multiplier = 0;
                                    else if (chosenOffer == 'Silver - 50% Retainer') multiplier = 0.5;
                                    else if (chosenOffer == 'Bronze - 80% Retainer') multiplier = 0.8;
                                    if (acc.Quoted_Retainer__c != null) {
                                        accUpdate.Quoted_Retainer_Amount__c = acc.Quoted_Retainer__c * multiplier;
                                    }

                                } else if (!creditFrozen && !noFileReturn && !hasPass) {
                                    accUpdate.Credit_Decision__c       = 'Full Retainer';
                                    accUpdate.Credit_Check_Complete__c = true;
                                    accUpdate.Quoted_Retainer_Amount__c = acc.Quoted_Retainer__c;
                                    accUpdate.Credit_Message__c        = 'Not Qualified by criteria.';

                                } else {
                                    // Unknown or Not Qualified
                                    accUpdate.Credit_Decision__c = 'Full Retainer';
                                    accUpdate.Credit_Check_Complete__c = true;
                                    accUpdate.Credit_Message__c  =
                                        'Unknown Error';
                                    accUpdate.Quoted_Retainer_Amount__c = acc.Quoted_Retainer__c;
                                }

                                // 5) Reset submitted flag
                                accUpdate.Credit_Check_Submitted__c = false;

                                accountsToUpdate.add(accUpdate);
                            } else {
                                // 200 but unexpected body shape
                                String details = '200 but response did not contain expected report structure.\nBody:\n' + res.getBody();
                                logError(acc.Id, 'APIIntegrationJob.execute', 'ERROR', code, req.getBody(), details);
                            }

                        } else if (code == 400) {
                            processValidationErrors(res, acc);
                        } else {
                            String details = 'Callout failed.\nStatus: ' + code + '\nBody:\n' + res.getBody();
                            logError(acc.Id, 'APIIntegrationJob.execute', 'ERROR', code, req.getBody(), details);
                        }

                    } catch (Exception ex) {
                        logError(acc.Id, 'APIIntegrationJob.execute', 'ERROR', null, null, 'Error for Account ' + acc.Id + ': ' + ex.getMessage(), ex);
                    }
                }

                if (!accountsToUpdate.isEmpty()) {
                    update accountsToUpdate;
                }
            } catch (Exception exOuter) {
                logError(null, 'APIIntegrationJob.execute', 'ERROR', null, null, 'Queueable failed before processing accounts: ' + exOuter.getMessage(), exOuter);
            }
        }
    }

    private static void processValidationErrors(HttpResponse response, Account acc) {
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

            // Account field is typically Text(255) - your original code truncates to 255
            String acctMsg = allMsgs;
            if (acctMsg.length() > 255) acctMsg = acctMsg.substring(0, 255);

            update new Account(
                Id = acc.Id,
                Credit_Decision__c        = 'Full Retainer',
                Credit_Report_Link__c     = 'Failed-400',
                Quoted_Retainer_Amount__c = acc.Quoted_Retainer__c,
                Credit_Check_Complete__c  = false,
                Credit_Message__c         = acctMsg
            );

            String logDetails =
                '400 validation returned.\nMessages:\n' + allMsgs + '\n\nBody:\n' + response.getBody();

            logError(acc.Id, 'processValidationErrors', 'WARN', 400, null, logDetails);

        } catch (Exception ex) {
            String logDetails = 'Failed to process 400 validation errors.\nBody:\n' + response.getBody();
            logError(acc.Id, 'processValidationErrors', 'ERROR', 400, null, logDetails, ex);
        }
    }

    public static void createReport(List<Id> accountIds) {
        System.enqueueJob(new APIIntegrationJob(accountIds));
    }

    // ===== API WRAPPER CLASSES =====
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