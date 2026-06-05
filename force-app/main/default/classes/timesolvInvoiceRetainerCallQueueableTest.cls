@IsTest
private class timesolvInvoiceRetainerCallQueueableTest {
    //–– STATIC SETUP –– 
    private static Id personRtId;
    private static String LONG_LINK;
    
    static {
        // Fetch the Person Account RecordType once
        personRtId = [
            SELECT Id 
              FROM RecordType 
             WHERE SObjectType = 'Account' 
               AND IsPersonType = true 
             LIMIT 1
        ].Id;
        
        // Build a 300+ char link
        LONG_LINK = buildLongLink();
    }
    
    private static String buildLongLink() {
        String s = 'http://payment.link/';
        while (s.length() < 300) {
            s += 'X';
        }
        return s;
    }
    
    private static Account createPersonAccount(
        String matterId,
        Decimal quoted,
        String email
    ) {
        Account acc = new Account(
            RecordTypeId          = personRtId,
            FirstName             = 'First' + matterId,
            LastName              = 'Last'  + matterId,
            TimeSolv_Matter_Id__c = matterId,
            Quoted_Retainer__c    = quoted,
            PersonEmail           = email
        );
        insert acc;
        return acc;
    }
    
    
    //–– HTTP CALL mocks ––    
    private class MockShortLink implements HttpCalloutMock {
        public HTTPResponse respond(HTTPRequest req) {
            HttpResponse res = new HttpResponse();
            res.setStatusCode(201);
            res.setHeader('Content-Type','application/json');
            res.setBody('{"Details":[{"Message":"http://payment.link/short"}]}');
            return res;
        }
    }
    
    private class MockLongLink implements HttpCalloutMock {
        public HTTPResponse respond(HTTPRequest req) {
            HttpResponse res = new HttpResponse();
            res.setStatusCode(200);
            res.setHeader('Content-Type','application/json');
            res.setBody('{"Details":[{"Message":"' + LONG_LINK + '"}]}');
            return res;
        }
    }
    
    private class Mock500Error implements HttpCalloutMock {
        public HTTPResponse respond(HTTPRequest req) {
            HttpResponse res = new HttpResponse();
            res.setStatusCode(500);
            res.setHeader('Content-Type','application/json');
            res.setBody('{"error":"server error"}');
            return res;
        }
    }
    
    
    //–– TESTS ––    
    
    static testMethod void testInvoiceRetainerSuccess() {
        // use quoted-retainer only
        Account acc = createPersonAccount('PRJ1', 100, 'a@x.com');
        Test.setMock(HttpCalloutMock.class, new MockShortLink());
        
        Test.startTest();
            System.enqueueJob(new timesolvInvoiceRetainerCallQueueable('PRJ1','tok'));
        Test.stopTest();
        
        acc = [SELECT Invoice_Retainer_URL1__c, Invoice_Retainer_URL2__c
                FROM Account WHERE Id = :acc.Id];
        System.assertEquals('http://payment.link/short',
                            acc.Invoice_Retainer_URL1__c);
        System.assertEquals(null,
                            acc.Invoice_Retainer_URL2__c);
    }
    
    static testMethod void testInvoiceRetainerLongLinkSplit() {
        Account acc = createPersonAccount('PRJ2', 200, 'b@x.com');
        Test.setMock(HttpCalloutMock.class, new MockLongLink());
        
        Test.startTest();
            System.enqueueJob(new timesolvInvoiceRetainerCallQueueable('PRJ2','tok'));
        Test.stopTest();
        
        acc = [SELECT Invoice_Retainer_URL1__c, Invoice_Retainer_URL2__c
                FROM Account WHERE Id = :acc.Id];
        System.assertEquals(LONG_LINK.substring(0,255),
                            acc.Invoice_Retainer_URL1__c);
        System.assertEquals(LONG_LINK.substring(255),
                            acc.Invoice_Retainer_URL2__c);
    }
    
    static testMethod void testZeroRetainerAmount() {
        // quoted = 0 should skip the callout
        Account acc = createPersonAccount('PRJ3', 0, 'c@x.com');
        
        Test.startTest();
            System.enqueueJob(new timesolvInvoiceRetainerCallQueueable('PRJ3','any'));
        Test.stopTest();
        
        acc = [SELECT Invoice_Retainer_URL1__c, Invoice_Retainer_URL2__c
                FROM Account WHERE Id = :acc.Id];
        System.assertEquals(null, acc.Invoice_Retainer_URL1__c);
        System.assertEquals(null, acc.Invoice_Retainer_URL2__c);
    }
    
    static testMethod void testNoAccountFound() {
        // no Account = no exception
        Test.startTest();
            System.enqueueJob(new timesolvInvoiceRetainerCallQueueable('NONE','any'));
        Test.stopTest();
    }
    
    static testMethod void testApiErrorStatus() {
        Account acc = createPersonAccount('PRJ4', 50, 'd@x.com');
        Test.setMock(HttpCalloutMock.class, new Mock500Error());
        
        Test.startTest();
            System.enqueueJob(new timesolvInvoiceRetainerCallQueueable('PRJ4','any'));
        Test.stopTest();
        
        acc = [SELECT Invoice_Retainer_URL1__c, Invoice_Retainer_URL2__c
                FROM Account WHERE Id = :acc.Id];
        System.assertEquals(null, acc.Invoice_Retainer_URL1__c);
        System.assertEquals(null, acc.Invoice_Retainer_URL2__c);
    }
}