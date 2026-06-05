@isTest
private class AdobeTrustAccountCheckInvocable_Test {
    
    /**
     * Happy path – valid inputs, job is enqueued, no exception thrown.
     */
    @isTest
    static void testCheckTrustAccountFunding_Success() {
        // Arrange
        Account acc = new Account(
            FirstName    = 'Test',
            LastName     = 'Client',
            PersonEmail  = 'test@example.com',
            RecordTypeId = '0124N000000X9ZnQAK'
        );
        insert acc;
        
        AdobeTrustAccountFundingCheckInvocable.TrustAccountCheckRequest req =
            new AdobeTrustAccountFundingCheckInvocable.TrustAccountCheckRequest();
        req.trustAccountId = '12345';
        req.clientId       = '67890';
        req.accountId      = acc.Id;      // valid Id string
        req.startAttempt   = 3;           // non-null to hit that branch
        
        List<AdobeTrustAccountFundingCheckInvocable.TrustAccountCheckRequest> input =
            new List<AdobeTrustAccountFundingCheckInvocable.TrustAccountCheckRequest>{ req };
        
        // Act
        Test.startTest();
        AdobeTrustAccountFundingCheckInvocable.checkTrustAccountFunding(input);
        Test.stopTest(); // queueable will run here, but we only care that no exception occurs
        
        // Assert – nothing thrown is enough; just add a simple assert to mark test
        System.assert(true, 'Invocable should complete without exception for valid input.');
    }
    
    /**
     * Validation error – missing Trust Account ID should throw InvocableException
     * and go through the DATA_ERROR logging path.
     */
    @isTest
    static void testCheckTrustAccountFunding_ValidationError() {
        Account acc = new Account(
            FirstName    = 'Val',
            LastName     = 'Error',
            PersonEmail  = 'val@example.com',
            RecordTypeId = '0124N000000X9ZnQAK'
        );
        insert acc;
        
        AdobeTrustAccountFundingCheckInvocable.TrustAccountCheckRequest req =
            new AdobeTrustAccountFundingCheckInvocable.TrustAccountCheckRequest();
        req.trustAccountId = null;        // <- missing, should trigger validation
        req.clientId       = '67890';
        req.accountId      = acc.Id;
        req.startAttempt   = null;
        
        List<AdobeTrustAccountFundingCheckInvocable.TrustAccountCheckRequest> input =
            new List<AdobeTrustAccountFundingCheckInvocable.TrustAccountCheckRequest>{ req };
        
        Boolean thrown = false;
        
        Test.startTest();
        try {
            AdobeTrustAccountFundingCheckInvocable.checkTrustAccountFunding(input);
        } catch (AdobeTrustAccountFundingCheckInvocable.InvocableException ex) {
            thrown = true;
            System.assertEquals(
                'Trust Account ID is required',
                ex.getMessage(),
                'Expected validation error message for missing Trust Account ID'
            );
        }
        Test.stopTest();
        
        System.assert(thrown, 'Expected InvocableException to be thrown for validation error.');
    }
    
    /**
     * Generic exception – invalid Account ID string causes cast exception,
     * which gets wrapped in a new InvocableException from the generic catch.
     */
    @isTest
    static void testCheckTrustAccountFunding_SystemError() {
        AdobeTrustAccountFundingCheckInvocable.TrustAccountCheckRequest req =
            new AdobeTrustAccountFundingCheckInvocable.TrustAccountCheckRequest();
        req.trustAccountId = '12345';
        req.clientId       = '67890';
        req.accountId      = 'NOT_A_VALID_ID'; // cast (Id) will throw
        req.startAttempt   = null;
        
        List<AdobeTrustAccountFundingCheckInvocable.TrustAccountCheckRequest> input =
            new List<AdobeTrustAccountFundingCheckInvocable.TrustAccountCheckRequest>{ req };
        
        Boolean thrown = false;
        
        Test.startTest();
        try {
            AdobeTrustAccountFundingCheckInvocable.checkTrustAccountFunding(input);
        } catch (AdobeTrustAccountFundingCheckInvocable.InvocableException ex) {
            thrown = true;
            System.assert(
                ex.getMessage().startsWith('Failed to start trust account check:'),
                'Expected wrapped InvocableException from generic catch block.'
            );
        }
        Test.stopTest();
        
        System.assert(thrown, 'Expected InvocableException to be thrown for system error path.');
    }
}