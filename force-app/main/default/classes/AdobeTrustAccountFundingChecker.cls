/**
 * @description Queueable class to check if a Trust Account is funded
 * Retries up to 10 times if the balance is still 0 or null
 * Once funded, activates the TimeSolv client to Active status
 */
public class AdobeTrustAccountFundingChecker implements Queueable, Database.AllowsCallouts {
    
    private String trustAccountId;
    private String clientId;
    private Id accountId;
    private Integer attemptNumber;
    private static final Integer MAX_ATTEMPTS = 10;
    
    public AdobeTrustAccountFundingChecker(String trustAccountId, String clientId, Id accountId) {
        this(trustAccountId, clientId, accountId, 1);
    }
    
    public AdobeTrustAccountFundingChecker(String trustAccountId, String clientId, Id accountId, Integer attemptNumber) {
        this.trustAccountId = trustAccountId;
        this.clientId = clientId;
        this.accountId = accountId;
        this.attemptNumber = attemptNumber;
    }
    
    public void execute(QueueableContext context) {
        try {
            TrustAccountBalanceResponse response = fetchTrustAccountBalance(trustAccountId);
            
            if (response == null) {
                handleFailedCallout();
                return;
            }
            
            Boolean isFunded = checkIfFunded(response);
            
            if (isFunded) {
                handleSuccessfulFunding(response);
            } else {
                handleNotFundedYet(response);
            }
            
        } catch (Exception e) {
            handleException(e);
        }
    }
    
    private TrustAccountBalanceResponse fetchTrustAccountBalance(String trustId) {
        try {
            HttpRequest req = new HttpRequest();
            req.setEndpoint(
                getBaseUrl() +
                '/trustAccountBalance?TrustAccountId=' +
                EncodingUtil.urlEncode(trustId,'UTF-8')
            );
            req.setMethod('GET');
            req.setHeader('Authorization',
                'Bearer ' + TimeSolvIntegrationTokenUtil.getBearerToken());
            
            HttpResponse res = new Http().send(req);
            
            if (res.getStatusCode() == 200) {
                return (TrustAccountBalanceResponse)
                       JSON.deserialize(res.getBody(),
                                        TrustAccountBalanceResponse.class);
            } else {
                // Only log on final attempt
                if (attemptNumber >= MAX_ATTEMPTS) {
                    AdobeFaErrorLogUtil.logApiError(
                        'AdobeTrustAccountFundingChecker',
                        'fetchTrustAccountBalance',
                        res,
                        accountId,
                        'TrustAccountId: ' + trustId + ', Attempt: ' + attemptNumber
                    );
                }
            }
        } catch (Exception e) {
            // Only log on final attempt
            if (attemptNumber >= MAX_ATTEMPTS) {
                AdobeFaErrorLogUtil.logError(
                    'AdobeTrustAccountFundingChecker',
                    'fetchTrustAccountBalance',
                    e,
                    accountId,
                    null,
                    'TrustAccountId: ' + trustId + ', Attempt: ' + attemptNumber,
                    AdobeFaErrorLogUtil.ErrorType.API_ERROR
                );
            }
        }
        return null;
    }
    
    private Boolean checkIfFunded(TrustAccountBalanceResponse response) {
        if (response == null || response.TrustAccountBalance == null) {
            return false;
        }
        
        Decimal balance = response.TrustAccountBalance.Balance;
        return balance != null && balance > 0;
    }
    
    private void handleSuccessfulFunding(TrustAccountBalanceResponse response) {
        // Make ALL callouts BEFORE any DML operations
        updateClientStatusToActive(clientId, accountId);
        
        // Update the Account record with the balance (DML operation)
        updateAccountWithBalance(true, response.TrustAccountBalance.Balance);
    }
    
    private void handleNotFundedYet(TrustAccountBalanceResponse response) {
        if (attemptNumber < MAX_ATTEMPTS) {
            AdobeTrustAccountFundingChecker nextAttempt = new AdobeTrustAccountFundingChecker(
                trustAccountId,
                clientId,
                accountId,
                attemptNumber + 1
            );
            System.enqueueJob(nextAttempt);
        } else {
            Decimal finalBalance = (response.TrustAccountBalance != null) 
                ? response.TrustAccountBalance.Balance 
                : null;
            
            Exception ex = new TrustAccountException(
                'Trust account not funded after ' + MAX_ATTEMPTS + ' attempts'
            );
            
            AdobeFaErrorLogUtil.logError(
                'AdobeTrustAccountFundingChecker',
                'handleNotFundedYet',
                ex,
                accountId,
                null,
                'TrustAccountId: ' + trustAccountId + 
                ', ClientId: ' + clientId +
                ', Final Balance: ' + finalBalance +
                ', Attempts: ' + MAX_ATTEMPTS,
                AdobeFaErrorLogUtil.ErrorType.DATA_ERROR
            );
            
            AdobeFaErrorLogUtil.createErrorTask(
                accountId,
                'Trust Account Not Funded',
                'Trust account was not funded after ' + MAX_ATTEMPTS + ' attempts.\n\n' +
                'Trust Account ID: ' + trustAccountId + '\n' +
                'Client ID: ' + clientId + '\n' +
                'Final Balance: ' + finalBalance + '\n\n' +
                'Please verify the trust account status in TimeSolv.',
                null
            );
            
            updateAccountWithBalance(false, 0);
        }
    }
    
    private void handleFailedCallout() {
        if (attemptNumber < MAX_ATTEMPTS) {
            AdobeTrustAccountFundingChecker nextAttempt = new AdobeTrustAccountFundingChecker(
                trustAccountId,
                clientId,
                accountId,
                attemptNumber + 1
            );
            System.enqueueJob(nextAttempt);
        } else {
            Exception ex = new TrustAccountException(
                'Callout failed after ' + MAX_ATTEMPTS + ' attempts'
            );
            
            AdobeFaErrorLogUtil.logError(
                'AdobeTrustAccountFundingChecker',
                'handleFailedCallout',
                ex,
                accountId,
                null,
                'TrustAccountId: ' + trustAccountId + 
                ', ClientId: ' + clientId +
                ', Attempts: ' + MAX_ATTEMPTS,
                AdobeFaErrorLogUtil.ErrorType.API_ERROR
            );
            
            AdobeFaErrorLogUtil.createErrorTask(
                accountId,
                'Trust Account Callout Failed',
                'Failed to check trust account balance after ' + MAX_ATTEMPTS + ' attempts.\n\n' +
                'Trust Account ID: ' + trustAccountId + '\n' +
                'Client ID: ' + clientId + '\n\n' +
                'Please check TimeSolv API connectivity and credentials.',
                null
            );
        }
    }
    
    private void handleException(Exception e) {
        AdobeFaErrorLogUtil.logError(
            'AdobeTrustAccountFundingChecker',
            'execute',
            e,
            accountId,
            null,
            'TrustAccountId: ' + trustAccountId + 
            ', ClientId: ' + clientId +
            ', Attempt: ' + attemptNumber,
            AdobeFaErrorLogUtil.ErrorType.SYSTEM_ERROR
        );
        
        // Only create Task on final attempt
        if (attemptNumber >= MAX_ATTEMPTS) {
            AdobeFaErrorLogUtil.createErrorTask(
                accountId,
                'Trust Account Check Failed',
                'Unexpected error while checking trust account funding.\n\n' +
                'Trust Account ID: ' + trustAccountId + '\n' +
                'Error: ' + e.getMessage() + '\n\n' +
                'Please review error logs for details.',
                null
            );
        }
    }
    
    private Boolean updateClientStatusToActive(String clientId, Id acctId) {
        try {
            HttpRequest req = new HttpRequest();
            req.setEndpoint(getBaseUrl() + '/client');
            req.setMethod('PUT');
            req.setHeader('Content-Type', 'application/json');
            req.setHeader('Authorization',
                'Bearer ' + TimeSolvIntegrationTokenUtil.getBearerToken());
            
            Map<String, Object> requestBody = new Map<String, Object>{
                'Id' => Integer.valueOf(clientId),
                'ClientStatus' => 'Active'
            };
            String requestBodyStr = JSON.serialize(requestBody);
            req.setBody(requestBodyStr);
            
            HttpResponse res = new Http().send(req);
            
            Boolean success = res.getStatusCode() == 200 || res.getStatusCode() == 201;
            
            if (!success) {
                AdobeFaErrorLogUtil.logApiError(
                    'AdobeTrustAccountFundingChecker',
                    'updateClientStatusToActive',
                    res,
                    acctId,
                    requestBodyStr
                );
                
                AdobeFaErrorLogUtil.createErrorTask(
                    acctId,
                    'Client Activation Failed',
                    'Failed to activate TimeSolv client.\n\n' +
                    'Client ID: ' + clientId + '\n' +
                    'HTTP Status: ' + res.getStatusCode() + '\n' +
                    'Response: ' + res.getBody() + '\n\n' +
                    'Please activate the client manually in TimeSolv.',
                    null
                );
            }
            
            return success;
            
        } catch (Exception e) {
            AdobeFaErrorLogUtil.logError(
                'AdobeTrustAccountFundingChecker',
                'updateClientStatusToActive',
                e,
                acctId,
                null,
                'ClientId: ' + clientId,
                AdobeFaErrorLogUtil.ErrorType.API_ERROR
            );
            
            AdobeFaErrorLogUtil.createErrorTask(
                acctId,
                'Client Activation Exception',
                'Exception occurred while activating TimeSolv client.\n\n' +
                'Client ID: ' + clientId + '\n' +
                'Error: ' + e.getMessage() + '\n\n' +
                'Please activate the client manually in TimeSolv.',
                null
            );
            
            return false;
        }
    }
    
    private static String getBaseUrl() {
        TimeSolv_Integration_Configuration__mdt config = [
            SELECT Endpoint_URL__c 
            FROM TimeSolv_Integration_Configuration__mdt 
            WHERE DeveloperName = 'Production'
            LIMIT 1
        ];
        return config.Endpoint_URL__c;
    }
    
    private void updateAccountWithBalance(Boolean isFunded, Decimal balance) {
    try {
        Account acc = new Account(
            Id = accountId,
            Timesolv_TrustAccount_Balance__c = balance
        );            
        if (isFunded == true) {
            acc.FA_Payment_Status__c = 'Trust Funded';
        }
        update acc;  //instead of using Database.update        
        /* delete block later
        Database.SaveResult result = Database.update(acc, false);        
        if (!result.isSuccess()) {
            String errorDetails = 'Account ID: ' + accountId + ', Balance: ' + balance + '\n';
            for (Database.Error err : result.getErrors()) {
                errorDetails += 'Error: ' + err.getMessage() + '\nFields: ' + err.getFields() + '\n';
            }                
            Exception ex = new TrustAccountException('Failed to update Account with balance');                
            AdobeFaErrorLogUtil.logError(
                'AdobeTrustAccountFundingChecker',
                'updateAccountWithBalance',
                ex,
                accountId,
                null,
                errorDetails,
                AdobeFaErrorLogUtil.ErrorType.SYSTEM_ERROR
            );
        }*/        
    } catch (Exception e) {
        AdobeFaErrorLogUtil.logError(
            'AdobeTrustAccountFundingChecker',
            'updateAccountWithBalance',
            e,
            accountId,
            null,
            'Balance: ' + balance + ', IsFunded: ' + isFunded,
            AdobeFaErrorLogUtil.ErrorType.SYSTEM_ERROR
        );
    }
    }
    
    // Response wrapper classes
    public class TrustAccountBalanceResponse {
        public StatusInfo Status { get; set; }
        public TrustAccountBalance TrustAccountBalance { get; set; }
    }
    
    public class StatusInfo {
        public Integer ResponseCode { get; set; }
        public String Message { get; set; }
    }
    
    public class TrustAccountBalance {
        public Long Id { get; set; }
        public Long ProjectId { get; set; }
        public String Name { get; set; }
        public Long TrustBankAccountId { get; set; }
        public Decimal ReplenishBelow { get; set; }
        public Decimal ReplenishTo { get; set; }
        public Decimal Balance { get; set; }
        public Boolean hasAutoPayInvoices { get; set; }
        public Boolean isDefault { get; set; }
        public Boolean isActive { get; set; }
        public Long LastUpdatedBy { get; set; }
        public String LastUpdatedDate { get; set; }
    }
    
    public class TrustAccountException extends Exception {}
}