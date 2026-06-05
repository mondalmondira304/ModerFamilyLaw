public class ZccInsertRecordsQueueable implements Queueable, Database.AllowsCallouts {
    private List<Zcc_Queue_Call_Details__c> recordsToInsert;
    private Id queueSummaryId;
    
    // Fields to support chaining the next page fetch
    private String nextPageToken;
    private String accessToken;
    private String fromDate;
    private String toDate;

    public ZccInsertRecordsQueueable(
        List<Zcc_Queue_Call_Details__c> recordsToInsert,
        Id queueSummaryId,
        String nextPageToken,
        String accessToken,
        String fromDate,
        String toDate
    ) {
        this.recordsToInsert = recordsToInsert;
        this.queueSummaryId  = queueSummaryId;
        this.nextPageToken   = nextPageToken;
        this.accessToken     = accessToken;
        this.fromDate        = fromDate;
        this.toDate          = toDate;
    }

    public void execute(QueueableContext context) {
        try {
            if (!recordsToInsert.isEmpty()) {
                // Associate each record with the summary ID
                for (Zcc_Queue_Call_Details__c record : recordsToInsert) {
                    record.Call_Summary__c = queueSummaryId;
                }
                // Insert the detail records
upsert recordsToInsert Engagement_Id__c;
                System.debug('Inserted ' + recordsToInsert.size() + ' Call Detail records.');
                
                // Update Account Lookup field
                updateAccountLookup(recordsToInsert);
            } else {
                System.debug('No records to insert.');
            }
            
            // Chain the next page fetch if a token is present
            if (!String.isBlank(nextPageToken)) {
                System.debug('Chaining next page fetch with token: ' + nextPageToken);
                System.enqueueJob(
                    new ZccFetchNextPageQueueable(
                        nextPageToken,
                        accessToken,
                        fromDate,
                        toDate,
                        queueSummaryId
                    )
                );
            } else {
                System.debug('No next page token. Pagination complete.');
            }
        } catch (Exception e) {
            System.debug('Error in ZccInsertRecordsQueueable: ' + e.getMessage());
        }
    }
    
    /**
     * Updates the Account lookup on each detail record by matching the normalized
     * Consumer_Number__c against Account.Phone and Account.PersonMobilePhone.
     */
    private void updateAccountLookup(List<Zcc_Queue_Call_Details__c> insertedRecords) {
        // 1) Collect the consumer numbers (normalized) from the inserted records.
        Set<String> consumerNumbersSet = new Set<String>();
        for (Zcc_Queue_Call_Details__c record : insertedRecords) {
            if (String.isNotBlank(record.Consumer_Number__c)) {
                String normalized = normalizePhone(record.Consumer_Number__c);
                if (String.isNotBlank(normalized)) {
                    consumerNumbersSet.add(normalized);
                }
            }
        }
        System.debug('Consumer numbers to process: ' + consumerNumbersSet);
        
        if (consumerNumbersSet.isEmpty()) {
            System.debug('No consumer numbers available for Account lookup.');
            return;
        }
        
        // 2) Query ONLY the Accounts whose Phone or PersonMobilePhone
        //    is in our set of normalized consumer numbers.
        List<Account> matchingAccounts = [
            SELECT Id, Phone, PersonMobilePhone
            FROM Account
            WHERE (Phone IN :consumerNumbersSet
                OR PersonMobilePhone IN :consumerNumbersSet)
        ];
        System.debug('Total Accounts queried: ' + matchingAccounts.size());
        
        // 3) Build a map from normalized phone -> Account.Id
        Map<String, Id> phoneToAccountIdMap = new Map<String, Id>();
        for (Account acc : matchingAccounts) {
            if (String.isNotBlank(acc.Phone)) {
                String phoneNormalized = normalizePhone(acc.Phone);
                if (String.isNotBlank(phoneNormalized)) {
                    phoneToAccountIdMap.put(phoneNormalized, acc.Id);
                }
            }
            if (String.isNotBlank(acc.PersonMobilePhone)) {
                String mobileNormalized = normalizePhone(acc.PersonMobilePhone);
                if (String.isNotBlank(mobileNormalized)) {
                    phoneToAccountIdMap.put(mobileNormalized, acc.Id);
                }
            }
        }
        System.debug('Matching Accounts found for normalized phones: ' + phoneToAccountIdMap);
        
        // 4) Update each record with the matching Account lookup.
        List<Zcc_Queue_Call_Details__c> recordsToUpdate = new List<Zcc_Queue_Call_Details__c>();
        for (Zcc_Queue_Call_Details__c record : insertedRecords) {
            if (String.isNotBlank(record.Consumer_Number__c)) {
                String normalizedConsumer = normalizePhone(record.Consumer_Number__c);
                if (phoneToAccountIdMap.containsKey(normalizedConsumer)) {
                    record.Account_Lookup__c = phoneToAccountIdMap.get(normalizedConsumer);
                    recordsToUpdate.add(record);
                    System.debug(
                        'Matched Consumer Number: ' + record.Consumer_Number__c +
                        ' normalized to: ' + normalizedConsumer +
                        ' -> Account ID: ' + phoneToAccountIdMap.get(normalizedConsumer)
                    );
                }
            }
        }
        
        if (!recordsToUpdate.isEmpty()) {
            update recordsToUpdate;
            System.debug('Updated Account Lookup for ' + recordsToUpdate.size() + ' records.');
        } else {
            System.debug('No matching accounts found for consumer numbers.');
        }
    }
    
    /**
     * Normalizes a phone number by:
     *   1. Returning null if the input is blank.
     *   2. Removing all non-digit characters.
     *   3. Returning only the last 10 digits (typical for US phone numbers).
     */
    private static String normalizePhone(String phoneStr) {
        // Step 1: Return null if blank.
        if (String.isBlank(phoneStr)) {
            return null;
        }
        
        // Step 2: Remove all non-digit characters.
        String digitsOnly = phoneStr.replaceAll('[^0-9]', '');
        
        // Step 3: Keep only the last 10 digits if available.
        if (digitsOnly.length() >= 10) {
            digitsOnly = digitsOnly.substring(digitsOnly.length() - 10);
        }
        
        // Step 4: Return the normalized phone number.
        return digitsOnly;
    }
}