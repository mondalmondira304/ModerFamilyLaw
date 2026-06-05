@isTest
public class PrequalSolutionsClientAPITest {

    @testSetup
    static void setup() {
        Account acc = new Account(
            LastName = 'API Test',
            FirstName = 'Test',
            PersonMailingStreet = '123 Test St',
            PersonMailingCity = 'TestCity',
            State_A__c = 'TEXAS',
            PersonMailingPostalCode = '75001',
            PersonMobilePhone = '7206184490',
            PersonEmail = 'test@example.com',
            Quoted_Retainer__c = 1000,
            Birthdate__c = Date.newInstance(2000, 1, 1),
            Annual_household_income__c = 100000,
            Social_Security_Number__c = '123-45-6789'
        );
        insert acc;
    }


    // 200 – generic success mock (pass decision)
    private class MockCallout implements HttpCalloutMock {
        public HTTPResponse respond(HTTPRequest req) {
            HttpResponse res = new HttpResponse();
            res.setHeader('Content-Type', 'application/json');
            res.setStatusCode(200);
            res.setBody(
                '{"api":{"response":{"data":{"reports":{"individual":[{'
                + '"temporary_shareable_link":"https://mock.link",'
                + '"result_status_type":"Success",'
                + '"decisioning":[{"criteria_set_name":"Gold - 0% Retainer","result":"pass"}],'
                + '"details":{"normalized":{"CREDIT_FROZEN_STATUS":{'
                + '"EquifaxIndicator":"false","ExperianIndicator":"false","TransUnionIndicator":"false"'
                + '}}}'
                + '}]}}}}}'
            );
            return res;
        }
    }

    // 200 – frozen mock (triggers creditFrozen branch)
    private class FrozenMockCallout implements HttpCalloutMock {
        public HTTPResponse respond(HTTPRequest req) {
            HttpResponse res = new HttpResponse();
            res.setHeader('Content-Type', 'application/json');
            res.setStatusCode(200);
            res.setBody(
                '{"api":{"response":{"data":{"reports":{"individual":[{'
                + '"temporary_shareable_link":"https://mock.link/frozen",'
                + '"result_status_type":"Success",'
                + '"decisioning":[{"criteria_set_name":"Gold - 0% Retainer","result":"fail"}],'
                + '"details":{"normalized":{'
                + '  "CREDIT_FROZEN_STATUS":{"EquifaxIndicator":"false","ExperianIndicator":"true","TransUnionIndicator":"false"},'
                + '  "CREDIT_FILE":{"ResultStatusType":"NoFileReturnedCreditFreeze"}'
                + '}}'
                + '}]}}}}}'
            );
            return res;
        }
    }

    // 200 – NoFileReturned / No Hit mock
    private class NoFileReturnMockCallout implements HttpCalloutMock {
        public HTTPResponse respond(HTTPRequest req) {
            HttpResponse res = new HttpResponse();
            res.setHeader('Content-Type', 'application/json');
            res.setStatusCode(200);
            res.setBody(
                '{"api":{"response":{"data":{"reports":{"individual":[{'
                + '"temporary_shareable_link":"https://mock.link/nofile",'
                + '"result_status_type":"NoFileReturnedNoHit",'
                + '"decisioning":[{"criteria_set_name":"Gold - 0% Retainer","result":"fail"}],'
                + '"details":{"normalized":{"CREDIT_FROZEN_STATUS":{'
                + '"EquifaxIndicator":"false","ExperianIndicator":"false","TransUnionIndicator":"false"},'
                + '"CREDIT_FILE":{"ResultStatusType":"NoFileReturned"}}}'
                + '}]}}}}}'
            );
            return res;
        }
    }

    // 400 – validation error mock
    private class Validation400MockCallout implements HttpCalloutMock {
        public HTTPResponse respond(HTTPRequest req) {
            HttpResponse res = new HttpResponse();
            res.setHeader('Content-Type', 'application/json');
            res.setStatusCode(400);
            res.setBody(
                '{"api":{"response":{"code":400,"errors":{"messages":{'
                + '"ssn":["Invalid format"],'
                + '"zip":["Bad zip"]'
                + '}}}}}'
            );
            return res;
        }
    }

    @isTest
    static void testCreateReport_Success() {
        Account acc = [SELECT Id FROM Account LIMIT 1];
        List<Id> accountIds = new List<Id>{ acc.Id };

        Test.setMock(HttpCalloutMock.class, new MockCallout());

        Test.startTest();
        PrequalSolutionsClientAPI.createReport(accountIds);
        Test.stopTest();

        Account updated = [
            SELECT Credit_Check_Complete__c,
                   Credit_Check_Submitted__c
            FROM Account
            WHERE Id = :acc.Id
        ];

        System.assertEquals(true,  updated.Credit_Check_Complete__c,
            'Check Complete flag should be true after successful callout');
        System.assertEquals(false, updated.Credit_Check_Submitted__c,
            'Submitted flag should be false after processing');
    }

    // Minimal frozen test: only assert incomplete flag
    @isTest
    static void testCreateReport_CreditFrozen_Incomplete() {
        Account acc = [SELECT Id FROM Account LIMIT 1];
        List<Id> accountIds = new List<Id>{ acc.Id };

        Test.setMock(HttpCalloutMock.class, new FrozenMockCallout());

        Test.startTest();
        PrequalSolutionsClientAPI.createReport(accountIds);
        Test.stopTest();

        Account updated = [
            SELECT Credit_Check_Complete__c
            FROM Account
            WHERE Id = :acc.Id
        ];

        System.assertEquals(false, updated.Credit_Check_Complete__c,
            'Frozen case should leave Credit_Check_Complete__c = false');
    }

    // NoFileReturned branch: should still mark complete
    @isTest
    static void testCreateReport_NoFileReturn_Complete() {
        Account acc = [SELECT Id, Quoted_Retainer__c FROM Account LIMIT 1];
        List<Id> accountIds = new List<Id>{ acc.Id };

        Test.setMock(HttpCalloutMock.class, new NoFileReturnMockCallout());

        Test.startTest();
        PrequalSolutionsClientAPI.createReport(accountIds);
        Test.stopTest();

        Account updated = [
            SELECT Credit_Check_Complete__c,
                   Quoted_Retainer_Amount__c
            FROM Account
            WHERE Id = :acc.Id
        ];

        System.assertEquals(true, updated.Credit_Check_Complete__c,
            'No-file-return case should still mark complete');

        System.assertEquals(acc.Quoted_Retainer__c, updated.Quoted_Retainer_Amount__c);
    }

    // 400 validation error → processValidationErrors()
    @isTest
    static void testCreateReport_400Validation() {
        Account acc = [SELECT Id FROM Account LIMIT 1];
        List<Id> accountIds = new List<Id>{ acc.Id };

        Test.setMock(HttpCalloutMock.class, new Validation400MockCallout());

        Test.startTest();
        PrequalSolutionsClientAPI.createReport(accountIds);
        Test.stopTest();

        Account updated = [
            SELECT Credit_Check_Complete__c,
                   Credit_Report_Link__c,
                   Credit_Message__c
            FROM Account
            WHERE Id = :acc.Id
        ];

        System.assertEquals(false, updated.Credit_Check_Complete__c,
            '400 validation should leave Credit_Check_Complete__c = false');
        System.assertEquals('Failed-400', updated.Credit_Report_Link__c);
        System.assert(updated.Credit_Message__c != null,
            '400 validation should persist a message');
    }
}