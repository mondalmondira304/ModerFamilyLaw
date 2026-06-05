/**
 * @description Invocable class to trigger Trust Account Funding Check from Flow
 */
public class AdobeTrustAccountFundingCheckInvocable {
    
    @InvocableMethod(
        label='Check Trust Account Funding'
        description='Starts a queueable job to check if a TimeSolv trust account is funded'
        category='Adobe Trust Account'
    )
    public static void checkTrustAccountFunding(List<TrustAccountCheckRequest> requests) {
        for (TrustAccountCheckRequest request : requests) {
            Id acctId = null;
            
            try {
                // Validate inputs
                if (String.isBlank(request.trustAccountId)) {
                    throw new InvocableException('Trust Account ID is required');
                }
                
                if (String.isBlank(request.clientId)) {
                    throw new InvocableException('Client ID is required');
                }
                
                if (String.isBlank(request.accountId)) {
                    throw new InvocableException('Account ID is required');
                }
                
                // Convert accountId to Id type for logging
                acctId = (Id) request.accountId;
                
                // Enqueue the job
                Integer startAttempt = request.startAttempt != null ? request.startAttempt : 1;
                AdobeTrustAccountFundingChecker checker = new AdobeTrustAccountFundingChecker(
                    request.trustAccountId,
                    request.clientId,
                    acctId,
                    startAttempt
                );
                
                System.enqueueJob(checker);
                
            } catch (InvocableException invEx) {
                System.debug('VALIDATION ERROR in Invocable Method');
                System.debug('Message: ' + invEx.getMessage());
                
                AdobeFaErrorLogUtil.logError(
                    'AdobeTrustAccountFundingCheckInvocable',
                    'checkTrustAccountFunding',
                    invEx,
                    acctId,
                    null,
                    'TrustAccountId: ' + request.trustAccountId + 
                    ', ClientId: ' + request.clientId +
                    ', AccountId: ' + request.accountId,
                    AdobeFaErrorLogUtil.ErrorType.DATA_ERROR
                );
                
                throw invEx; 
                
            } catch (Exception e) {
                System.debug('EXCEPTION in Invocable Method');
                System.debug('Message: ' + e.getMessage());
                System.debug('Type: ' + e.getTypeName());
                
                AdobeFaErrorLogUtil.logError(
                    'AdobeTrustAccountFundingCheckInvocable',
                    'checkTrustAccountFunding',
                    e,
                    acctId,
                    null,
                    'TrustAccountId: ' + request.trustAccountId + 
                    ', ClientId: ' + request.clientId +
                    ', AccountId: ' + request.accountId,
                    AdobeFaErrorLogUtil.ErrorType.SYSTEM_ERROR
                );
                
                throw new InvocableException('Failed to start trust account check: ' + e.getMessage());
            }
        }
    }
    
    public class TrustAccountCheckRequest {
        
        @InvocableVariable(
            label='Trust Account ID'
            description='The TimeSolv Trust Account ID to check (required)'
            required=true
        )
        public String trustAccountId;
        
        @InvocableVariable(
            label='Client ID'
            description='The TimeSolv Client ID to activate when funded (required)'
            required=true
        )
        public String clientId;
        
        @InvocableVariable(
            label='Account ID'
            description='The Salesforce Account ID to update with the balance (required)'
            required=true
        )
        public String accountId;
        
        @InvocableVariable(
            label='Start Attempt Number'
            description='Starting attempt number (optional, defaults to 1)'
            required=false
        )
        public Integer startAttempt;
    }
    
    public class InvocableException extends Exception {}
}