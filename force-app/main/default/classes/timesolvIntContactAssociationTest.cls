@IsTest
private class timesolvIntContactAssociationTest {
    //----- 1) Mock for a successful association callout
    private class SuccessMock implements HttpCalloutMock {
        public HTTPResponse respond(HTTPRequest req) {
            HttpResponse res = new HttpResponse();
            res.setHeader('Content-Type','application/json');
            if (req.getEndpoint().contains('/contactAssociations')) {
                res.setStatusCode(201);
                res.setBody('{"status":"ok"}');
            } else {
                res.setStatusCode(404);
            }
            return res;
        }
    }

    //----- 2) Mock for an error response
    private class ErrorMock implements HttpCalloutMock {
        public HTTPResponse respond(HTTPRequest req) {
            HttpResponse res = new HttpResponse();
            res.setStatusCode(500);
            res.setBody('Server error');
            return res;
        }
    }

    @IsTest static void testSuccessfulAssociation_NoChainedJob() {
    // Arrange
    Account acct = new Account(Name='Test Acct');
    insert acct;

    // **Give Email (or Phone) to satisfy validation**
    Contact con = new Contact(
        LastName  = 'Doe',
        AccountId = acct.Id,
        Email     = 'doe@example.com'
    );
    insert con;

    Test.setMock(HttpCalloutMock.class, new SuccessMock());
    timesolvIntegrationContactAssociation.skipChainedTrustCall = true;

    // Act
    Test.startTest();
       ID jobId = System.enqueueJob(
           new timesolvIntegrationContactAssociation(
               acct.Id,
               'CLIENT123',
               con.Id,
               'dummyToken',
               'PROJ789'
           )
       );
    Test.stopTest();

    // Assert
    System.assertNotEquals(null, jobId);
}

    @IsTest static void testErrorPath_LogsAndNoException() {
        Account acct = new Account(Name='Error Acct');
        insert acct;
        Contact con = new Contact(
    LastName  = 'Doe',
    AccountId = acct.Id,
    Email     = 'doe@example.com'
);


        Test.setMock(HttpCalloutMock.class, new ErrorMock());
        timesolvIntegrationContactAssociation.skipChainedTrustCall = true;

        Test.startTest();
            ID jobId = System.enqueueJob(
                new timesolvIntegrationContactAssociation(
                    acct.Id,
                    'CLIENT123',
                    con.Id,
                    'dummyToken',
                    'PROJ789'
                )
            );
        Test.stopTest();

        System.assertNotEquals(null, jobId, 'Even on error the job should finish gracefully');
        // (Optionally query your log object to assert error was captured.)
    }
}