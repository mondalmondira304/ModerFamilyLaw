/**
 * TS_TrustBalanceSync_Batch
 *
 * Synchronizes trust balance information from TimeSolv into the TS_Finance_Widget__c object.
 *
 *
 * Usage:
 * Database.executeBatch(new TS_TrustBalanceSync_Batch(), 100);
 */
public with sharing class TS_TrustBalanceSync_Batch implements Database.Batchable<SObject>, Database.AllowsCallouts, Database.Stateful {

    private Integer totalSuccess = 0;
    private Integer totalErrors  = 0;

    public Database.QueryLocator start(Database.BatchableContext bc) {
        return Database.getQueryLocator([
            SELECT Id,
       Matter_ID_Full__c,
       Client_Name__r.Timesolv_trustAccount_Id__c,
       Account__r.Id
FROM Matters__c
WHERE Matter_ID_Full__c != null
  AND Client_Name__r.Timesolv_trustAccount_Id__c != null

        ]);
    }

    public void execute(Database.BatchableContext bc, List<Matters__c> matters) {
        List<TS_Finance_Widget__c> widgetsToUpsert = new List<TS_Finance_Widget__c>();

        String baseUrl = timesolvIntegrationTokenUtil.getTimesolvBaseUrl();
        String bearer  = timesolvIntegrationTokenUtil.getBearerToken();

        for (Matters__c m : matters) {
String accountTrustId = (m.Client_Name__r == null) ? null: String.valueOf(m.Client_Name__r.Timesolv_trustAccount_Id__c);            
            if (String.isBlank(accountTrustId)) {
                System.debug(LoggingLevel.WARN, 'Skipping Matter ' + m.Id + ' because Account trust id is blank.');
                totalErrors++;
                continue;
            }

            if (Limits.getCallouts() >= Limits.getLimitCallouts()) {
                System.debug(LoggingLevel.WARN, 'Callout limit reached. Breaking loop to process remaining records in the next batch.');
                break;
            }

            try {
                HttpRequest req = new HttpRequest();
                String q = EncodingUtil.urlEncode(accountTrustId, 'UTF-8');
                req.setEndpoint(baseUrl + '/trustAccountBalance?TrustAccountId=' + q);
                req.setMethod('GET');
                req.setHeader('Authorization', 'Bearer ' + bearer);
                req.setTimeout(120000);

                HttpResponse res = new Http().send(req);

                if (res.getStatusCode() == 200 && res.getBody() != null) {
                    Map<String, Object> payload   = (Map<String, Object>) JSON.deserializeUntyped(res.getBody());
                    Map<String, Object> trustData = (Map<String, Object>) payload.get('TrustAccountBalance');

                    if (trustData != null) {
                        TS_Finance_Widget__c wid = new TS_Finance_Widget__c();
                        wid.Matter_Id__c = normKey(m.Matter_ID_Full__c); // from Matter
                        wid.Matter__c    = m.Id;                         // link back to Matter
                        wid.Timesolv_Trust_Balance__c           = (Decimal) trustData.get('Balance');
                        wid.Timesolv_Trust_Replenish_Below__c   = (Decimal) trustData.get('ReplenishBelow');
                        wid.Timesolv_Trust_Replenish_To__c      = (Decimal) trustData.get('ReplenishTo');

                        widgetsToUpsert.add(wid);
                    } else {
                        System.debug(LoggingLevel.WARN, 'No TrustAccountBalance node for Account Trust Id ' + accountTrustId + '. Body: ' + res.getBody());
                        totalErrors++;
                    }
                } else {
                    System.debug(LoggingLevel.ERROR,
                        'API call failed for Matter ' + m.Id +
                        '. Account Trust Id: ' + accountTrustId +
                        '. Status: ' + res.getStatusCode() +
                        '. Body: ' + res.getBody());
                    totalErrors++;
                }

            } catch (Exception e) {
                System.debug(LoggingLevel.ERROR,
                    'Unexpected error for Matter ' + m.Id +
                    ' (Account Trust Id: ' + accountTrustId + '): ' +
                    e.getTypeName() + ' - ' + e.getMessage());
                totalErrors++;
            }
        }

        if (!widgetsToUpsert.isEmpty()) {
            totalSuccess += widgetsToUpsert.size(); // optimistic; adjust on failures below
            Database.UpsertResult[] upsertResults =
                Database.upsert(widgetsToUpsert, TS_Finance_Widget__c.Fields.Matter_Id__c, false);

            for (Integer i = 0; i < upsertResults.size(); i++) {
                if (!upsertResults[i].isSuccess()) {
                    Database.Error err = upsertResults[i].getErrors()[0];
                    System.debug(LoggingLevel.ERROR,
                        'DML Error on Matter_Id__c ' + widgetsToUpsert[i].Matter_Id__c + ': ' +
                        err.getMessage() + ' (' + err.getStatusCode() + ')');
                    totalSuccess--;
                    totalErrors++;
                }
            }
        }
    }

    public void finish(Database.BatchableContext bc) {
        System.debug('--- TS_TrustBalanceSync_Batch FINISHED ---');
        System.debug('Total records successfully processed: ' + totalSuccess);
        System.debug('Total records with errors: ' + totalErrors);
        System.debug('------------------------------------------');
    }

    private static String normKey(String s) {
        return String.isBlank(s) ? null : s.replace(' ', '').trim().toUpperCase();
    }
}