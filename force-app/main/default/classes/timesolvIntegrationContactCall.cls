/**
 * @description Queueable Apex job to create a Contact in TimeSolv for a single Account,
 *
 * @author     Sanders
 * @date       2025-04-30
 */
public class timesolvIntegrationContactCall implements Queueable, Database.AllowsCallouts {

    @TestVisible
    public static Boolean skipAssociation = false;

    private Id     accId;
    private String clientId;
    private String bearerToken;
    private String projectId;

    private static final String BASE_URL         = initBaseUrl();
    private static final String CONTACT_ENDPOINT = BASE_URL + '/contact';

    public timesolvIntegrationContactCall(
        Id accId,
        String clientId,
        String bearerToken,
        String projectId
    ) {
        this.accId       = accId;
        this.clientId    = clientId;
        this.bearerToken = bearerToken;
        this.projectId   = projectId;
    }

    public void execute(QueueableContext qc) {

        Account acc;

        try {
            // 1) Query basic contact data + PersonAccount Mailing address fields
            acc = [
                SELECT Id,
                       Salutation,
                       PersonEmail,
                       FirstName,
                       LastName,
                       Phone,
                       PersonMobilePhone,
                       PersonMailingStreet,
                       PersonMailingCity,
                       PersonMailingState,
                       PersonMailingPostalCode
                  FROM Account
                 WHERE Id = :accId
            ];

            // 2) Build payload
            ContactWrapper payload = new ContactWrapper();
            payload.FirstName             = acc.FirstName;
            payload.LastName              = acc.LastName;
            payload.Email                 = acc.PersonEmail;
            payload.OfficePhone           = acc.Phone;
            payload.CellPhone             = acc.PersonMobilePhone;
            payload.Title                 = acc.Salutation;
            payload.CreatePortalAccess    = true;
            payload.AutomaticPortalAccess = true;

            // 3) Use PersonMailing fields for street, city, state & postal code
            payload.AddressLine1 = acc.PersonMailingStreet;
            payload.City         = acc.PersonMailingCity;

            payload.State        = normalizeStateCode(acc.PersonMailingState);

            payload.PostalCode   = acc.PersonMailingPostalCode;

            // 4) Serialize as list
            List<ContactWrapper> wrapperList = new List<ContactWrapper>{ payload };

            // 5) Perform callout
            HttpRequest req = new HttpRequest();
            req.setEndpoint(CONTACT_ENDPOINT);
            req.setMethod('POST');
            req.setHeader('Content-Type','application/json');
            req.setHeader('Authorization','Bearer ' + bearerToken);
            req.setBody(JSON.serialize(wrapperList));

            HttpResponse res;
            try {
                res = new Http().send(req);
            } catch (Exception e) {
                TimeSolvIntegrationLogUtil.logError(
                    acc.Id,
                    TimeSolvIntegrationLogUtil.INTEGRATION_TYPE_CONTACT,
                    'Callout exception: ' + e.getMessage(),
                    e
                );

                try {
                    TimeSolvIntegrationStatusTask.updateIntegrationStatusTask(
                        acc,
                        'Contact Creation',
                        'Error',
                        'Callout exception: ' + e.getMessage(),
                        null
                    );
                } catch (Exception ignore) {}

                return;
            }

            // 6) Handle API response & logging
            List<TimeSolv_Integration_Log__c> logs = new List<TimeSolv_Integration_Log__c>();
            Boolean success = false;
            String newContactId;

            if (res.getStatusCode() == 200 || res.getStatusCode() == 201) {
                ContactApiResponse respObj =
                    (ContactApiResponse) JSON.deserialize(
                        res.getBody(),
                        ContactApiResponse.class
                    );
                if (respObj != null && respObj.Details != null && !respObj.Details.isEmpty()) {
                    newContactId = String.valueOf(respObj.Details[0].Id);
                    success = true;
                } else {
                    logs.add(TimeSolvIntegrationLogUtil.logWarning(
                        acc.Id,
                        TimeSolvIntegrationLogUtil.INTEGRATION_TYPE_CONTACT,
                        'No Contact ID returned in response'
                    ));
                }
            } else {
                logs.add(TimeSolvIntegrationLogUtil.logError(
                    acc.Id,
                    TimeSolvIntegrationLogUtil.INTEGRATION_TYPE_CONTACT,
                    'Failed (' + res.getStatusCode() + '): ' + res.getBody(),
                    null
                ));
            }

            // 7) Insert logs if any
            if (!logs.isEmpty()) {
                insert logs;
            }

            // 8) On success, update Account, status and enqueue association
            if (success) {
                acc.TimeSolv_Contact_Id__c = newContactId;
                update acc;

                TimeSolvIntegrationStatusTask.updateIntegrationStatusTask(
                    acc,
                    'Contact Creation',
                    'Success',
                    'Contact ID: ' + newContactId,
                    null
                );

                if (!skipAssociation
                    && clientId != null
                    && projectId != null
                    && Limits.getQueueableJobs() < Limits.getLimitQueueableJobs()
                ) {
                    System.enqueueJob(
                        new timesolvIntegrationContactAssociation(
                            acc.Id,
                            clientId,
                            newContactId,
                            bearerToken,
                            projectId
                        )
                    );

                    TimeSolvIntegrationStatusTask.updateIntegrationStatusTask(
                        acc,
                        'Contact Association',
                        'Queued',
                        'Contact Association has been queued',
                        null
                    );
                } else if (!skipAssociation){
                    TimeSolv_Integration_Log__c warn =
                        TimeSolvIntegrationLogUtil.logWarning(
                            acc.Id,
                            TimeSolvIntegrationLogUtil.INTEGRATION_TYPE_CONTACT,
                            'Could not enqueue Contact Association'
                        );
                    insert warn;

                    TimeSolvIntegrationStatusTask.updateIntegrationStatusTask(
                        acc,
                        'Contact Association',
                        'Warning',
                        'Could not enqueue Contact Association',
                        warn.Id
                    );
                }
            } else {
                // 9) On failure, update status task with first log message or generic error
                try {
                    TimeSolvIntegrationStatusTask.updateIntegrationStatusTask(
                        acc,
                        'Contact Creation',
                        'Error',
                        logs.isEmpty()
                            ? 'Unknown error'
                            : logs[0].Message__c,
                        logs.isEmpty() ? null : logs[0].Id
                    );
                } catch (Exception ignore) {}
            }

        } catch (Exception e) {
            Id safeAccId = (acc != null ? acc.Id : accId);

            TimeSolvIntegrationLogUtil.logError(
                safeAccId,
                TimeSolvIntegrationLogUtil.INTEGRATION_TYPE_CONTACT,
                'Unhandled exception in execute(): ' + e.getMessage(),
                e
            );

            try {
                if (acc == null && accId != null) {
                    acc = new Account(Id = accId);
                }
                if (acc != null) {
                    TimeSolvIntegrationStatusTask.updateIntegrationStatusTask(
                        acc,
                        'Contact Creation',
                        'Error',
                        'Unhandled exception: ' + e.getMessage(),
                        null
                    );
                }
            } catch (Exception ignore) {}

            return;
        }
    }

    private static String properCase(String raw) {
        if (raw == null) return null;
        String trimmed = raw.trim().toLowerCase();
        return trimmed.length() > 0
            ? trimmed.substring(0,1).toUpperCase() + trimmed.substring(1)
            : trimmed;
    }

    
    private static String normalizeStateCode(String rawState) {
        if (String.isBlank(rawState)) {
            return null;
        }

        String trimmed = rawState.trim();

        if (trimmed.length() == 2) {
            return trimmed.toUpperCase();
        }

        String key = trimmed.toLowerCase();

        if (STATE_NAME_TO_CODE.containsKey(key)) {
            return STATE_NAME_TO_CODE.get(key);
        }

        return null;
    }

    private static final Map<String, String> STATE_NAME_TO_CODE = new Map<String, String>{
        'alabama' => 'AL',
        'alaska' => 'AK',
        'arizona' => 'AZ',
        'arkansas' => 'AR',
        'california' => 'CA',
        'colorado' => 'CO',
        'connecticut' => 'CT',
        'delaware' => 'DE',
        'district of columbia' => 'DC',
        'florida' => 'FL',
        'georgia' => 'GA',
        'hawaii' => 'HI',
        'idaho' => 'ID',
        'illinois' => 'IL',
        'indiana' => 'IN',
        'iowa' => 'IA',
        'kansas' => 'KS',
        'kentucky' => 'KY',
        'louisiana' => 'LA',
        'maine' => 'ME',
        'maryland' => 'MD',
        'massachusetts' => 'MA',
        'michigan' => 'MI',
        'minnesota' => 'MN',
        'mississippi' => 'MS',
        'missouri' => 'MO',
        'montana' => 'MT',
        'nebraska' => 'NE',
        'nevada' => 'NV',
        'new hampshire' => 'NH',
        'new jersey' => 'NJ',
        'new mexico' => 'NM',
        'new york' => 'NY',
        'north carolina' => 'NC',
        'north dakota' => 'ND',
        'ohio' => 'OH',
        'oklahoma' => 'OK',
        'oregon' => 'OR',
        'pennsylvania' => 'PA',
        'rhode island' => 'RI',
        'south carolina' => 'SC',
        'south dakota' => 'SD',
        'tennessee' => 'TN',
        'texas' => 'TX',
        'utah' => 'UT',
        'vermont' => 'VT',
        'virginia' => 'VA',
        'washington' => 'WA',
        'west virginia' => 'WV',
        'wisconsin' => 'WI',
        'wyoming' => 'WY',
        'puerto rico' => 'PR',
        'virgin islands' => 'VI',
        'american samoa' => 'AS',
        'guam' => 'GU',
        'northern mariana islands' => 'MP',
        'marshall islands' => 'MH',
        'palau' => 'PW'
    };

    private static String initBaseUrl() {
        try {
            TimeSolv_Integration_Configuration__mdt ep =
                [SELECT Endpoint_URL__c
                   FROM TimeSolv_Integration_Configuration__mdt
                  WHERE Label = 'Production'
                  LIMIT 1];
            return ep != null ? ep.Endpoint_URL__c : '';
        } catch (Exception e) {
            System.debug('❌ [ContactCall] initBaseUrl failed: ' + e.getMessage());
            return '';
        }
    }

    public class ContactWrapper {
        public String  FirstName             { get; set; }
        public String  LastName              { get; set; }
        public String  Email                 { get; set; }
        public String  OfficePhone           { get; set; }
        public String  CellPhone             { get; set; }
        public String  Title                 { get; set; }
        public Boolean CreatePortalAccess    { get; set; }
        public Boolean AutomaticPortalAccess { get; set; }
        public String  AddressLine1          { get; set; }
        public String  City                  { get; set; }
        public String  State                 { get; set; }
        public String  PostalCode            { get; set; }
    }

    public class ContactDetail { public Integer Id; }
    public class ContactApiResponse { public List<ContactDetail> Details; }
}