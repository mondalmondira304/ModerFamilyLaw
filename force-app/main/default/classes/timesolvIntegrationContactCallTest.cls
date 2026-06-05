@IsTest(SeeAllData=false)
private class timesolvIntegrationContactCallTest {

    // -------------------- MOCKS --------------------

    private class SuccessMock implements HttpCalloutMock {
        public HTTPResponse respond(HTTPRequest req) {
            HttpResponse res = new HttpResponse();
            if (req.getEndpoint().contains('/contact')) {
                res.setStatusCode(201);
                res.setBody('{"Details":[{"Id":12345}]}');
            } else {
                res.setStatusCode(400);
                res.setBody('{}');
            }
            return res;
        }
    }

    private class FailureMock implements HttpCalloutMock {
        public HTTPResponse respond(HTTPRequest req) {
            HttpResponse res = new HttpResponse();
            res.setStatusCode(500);
            res.setBody('Server error');
            return res;
        }
    }

    private class EmptyDetailsMock implements HttpCalloutMock {
        public HTTPResponse respond(HTTPRequest req) {
            HttpResponse res = new HttpResponse();
            if (req.getEndpoint().contains('/contact')) {
                res.setStatusCode(200);
                res.setBody('{"Details":[]}');
            } else {
                res.setStatusCode(404);
                res.setBody('{}');
            }
            return res;
        }
    }

    // Triggers JSON.deserialize exception inside success-status path -> outer catch
    private class BadJsonMock implements HttpCalloutMock {
        public HTTPResponse respond(HTTPRequest req) {
            HttpResponse res = new HttpResponse();
            res.setStatusCode(200);
            res.setBody('NOT_JSON');
            return res;
        }
    }

    // Triggers callout exception catch around Http.send
    private class ThrowingMock implements HttpCalloutMock {
        public HTTPResponse respond(HTTPRequest req) {
            throw new CalloutException('Simulated callout failure');
        }
    }

    // -------------------- TEST SETUP --------------------

    @TestSetup
    static void createPersonAccount() {
        RecordType prt = [
            SELECT Id
              FROM RecordType
             WHERE SObjectType='Account'
               AND IsPersonType=true
             LIMIT 1
        ];

        Account pa = new Account(
            RecordTypeId        = prt.Id,
            FirstName           = 'Test',
            LastName            = 'User',
            PersonEmail         = 'testuser@example.com',
            Phone               = '555-1234',
            PersonMobilePhone   = '555-5678',
            PersonMailingStreet = '1 Main',
            PersonMailingCity   = 'Denver',
            PersonMailingState  = 'WASHINGTON',
            PersonMailingPostalCode = '80014'
        );
        insert pa;
    }

    private static Account getAcc() {
        return [
            SELECT Id, PersonMailingState, TimeSolv_Contact_Id__c
              FROM Account
             WHERE PersonEmail='testuser@example.com'
             LIMIT 1
        ];
    }

    private static Task getStatusTask(Id accId) {
        return [
            SELECT Status, Description
              FROM Task
             WHERE WhatId=:accId
               AND Subject='TimeSolv Integration Status'
             LIMIT 1
        ];
    }

    // -------------------- TESTS --------------------

    @IsTest
    static void testSuccess_skipAssociation() {
        timesolvIntegrationContactCall.skipAssociation = false;

        Account acc = getAcc();
        Test.setMock(HttpCalloutMock.class, new SuccessMock());

        Test.startTest();
            System.enqueueJob(new timesolvIntegrationContactCall(
                acc.Id, null, 'fake-token', null
            ));
        Test.stopTest();

        acc = [SELECT TimeSolv_Contact_Id__c FROM Account WHERE Id=:acc.Id];
        System.assertEquals('12345', acc.TimeSolv_Contact_Id__c);

        Task t = getStatusTask(acc.Id);
        System.assertEquals('In Progress', t.Status);
        System.assert(t.Description.contains('Contact Creation: Success - Contact ID: 12345'));
        System.assert(t.Description.contains('Contact Association: Warning - Could not enqueue Contact Association'));
    }

    @IsTest
    static void testFailure_500() {
        timesolvIntegrationContactCall.skipAssociation = true;

        Account acc = getAcc();
        Test.setMock(HttpCalloutMock.class, new FailureMock());

        Test.startTest();
            System.enqueueJob(new timesolvIntegrationContactCall(
                acc.Id, null, 'fake-token', null
            ));
        Test.stopTest();

        acc = [SELECT TimeSolv_Contact_Id__c FROM Account WHERE Id=:acc.Id];
        System.assertEquals(null, acc.TimeSolv_Contact_Id__c);

        Task t = getStatusTask(acc.Id);
        System.assertEquals('Blocked', t.Status);
        System.assert(t.Description.contains('Contact Creation: Error'));
    }

    @IsTest
    static void testEmptyDetails_andTwoLetterNormalize() {
        timesolvIntegrationContactCall.skipAssociation = true;

        Account acc = getAcc();
        acc.PersonMailingState = 'wa';
        update acc;

        Test.setMock(HttpCalloutMock.class, new EmptyDetailsMock());

        Test.startTest();
            System.enqueueJob(new timesolvIntegrationContactCall(
                acc.Id, null, 'fake-token', null
            ));
        Test.stopTest();

        acc = [SELECT TimeSolv_Contact_Id__c FROM Account WHERE Id=:acc.Id];
        System.assertEquals(null, acc.TimeSolv_Contact_Id__c);

        Integer logCount = [
            SELECT COUNT()
              FROM TimeSolv_Integration_Log__c
             WHERE Account__c = :acc.Id
        ];
        System.assert(logCount > 0);
    }

    @IsTest
    static void testBadJson_outerCatch() {
        timesolvIntegrationContactCall.skipAssociation = true;

        Account acc = getAcc();
        Test.setMock(HttpCalloutMock.class, new BadJsonMock());

        Test.startTest();
            System.enqueueJob(new timesolvIntegrationContactCall(
                acc.Id, null, 'fake-token', null
            ));
        Test.stopTest();

        acc = [SELECT TimeSolv_Contact_Id__c FROM Account WHERE Id=:acc.Id];
        System.assertEquals(null, acc.TimeSolv_Contact_Id__c);

        Task t = getStatusTask(acc.Id);
        System.assertEquals('Blocked', t.Status);
        System.assert(t.Description.contains('Contact Creation: Error'));
    }

    @IsTest
    static void testCalloutException_path() {
        timesolvIntegrationContactCall.skipAssociation = true;

        Account acc = getAcc();
        Test.setMock(HttpCalloutMock.class, new ThrowingMock());

        Test.startTest();
            System.enqueueJob(new timesolvIntegrationContactCall(
                acc.Id, null, 'fake-token', null
            ));
        Test.stopTest();

        Task t = getStatusTask(acc.Id);
        System.assertEquals('Blocked', t.Status);
        System.assert(t.Description.contains('Contact Creation: Error'));
    }
}