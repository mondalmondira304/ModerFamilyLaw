@IsTest
private class AdobeFAMatterFileLinkHandlerTest {

    private static final String TEST_AGREEMENT_ID = 'CBJCHBCAABAAtest123';
    private static final String PC_RECORD_TYPE_ID = '0124N000000X9ZnQAK';

    @TestSetup
    static void setupData() {
        Account acc = new Account(
            LastName = 'Test FA Link',
            RecordTypeId = PC_RECORD_TYPE_ID,
            FA_Portal_AgreementId__c = TEST_AGREEMENT_ID
        );
        insert acc;

        Account opposingParty = new Account(
            LastName = 'Opposing Party Test',
            RecordTypeId = PC_RECORD_TYPE_ID
        );
        insert opposingParty;

        MFL_Office__c office = new MFL_Office__c(Name = 'Test Office');
        insert office;
    }

    private static Account getTestAccount() {
        return [SELECT Id, FA_Portal_AgreementId__c, PersonContactId FROM Account WHERE FA_Portal_AgreementId__c = :TEST_AGREEMENT_ID LIMIT 1];
    }

    private static Account getOpposingParty() {
        return [SELECT Id FROM Account WHERE LastName = 'Opposing Party Test' LIMIT 1];
    }

    private static Id createTestFile(Id accountId) {
        ContentVersion cv = new ContentVersion(
            Title = 'Fee Agreement Test',
            PathOnClient = 'Fee Agreement Test.pdf',
            VersionData = Blob.valueOf('test pdf content'),
            FirstPublishLocationId = accountId
        );
        insert cv;
        return [SELECT ContentDocumentId FROM ContentVersion WHERE Id = :cv.Id].ContentDocumentId;
    }

   private static Id createTestMatter(Id accountId) {
    Account acc = [SELECT PersonContactId FROM Account WHERE Id = :accountId];
    Account op = getOpposingParty();
    MFL_Office__c office = [SELECT Id FROM MFL_Office__c WHERE Name = 'Test Office' LIMIT 1];

    Matters__c m = new Matters__c(
        Name = 'Test v Test',
        Case_Type__c = 'Adoption',
        Client__c = acc.PersonContactId,
        Opposing_Party_a__c = op.Id,
        Primary_Attorney__c = UserInfo.getUserId(),
        MFL_Office__c = office.Id,
                Hire_Date__c = Date.today()

    );
    insert m;
    return m.Id;
}
    @IsTest
    static void testPdfSaved_NoMatter() {
        Account acc = getTestAccount();
        Id docId = createTestFile(acc.Id);

        AdobeFAMatterFileLinkHandler.Request req = new AdobeFAMatterFileLinkHandler.Request();
        req.accountId = acc.Id;
        req.contentDocumentId = docId;
        req.fileTitle = 'Fee Agreement Test';

        Test.startTest();
        List<AdobeFAMatterFileLinkHandler.Response> results =
            AdobeFAMatterFileLinkHandler.link(new List<AdobeFAMatterFileLinkHandler.Request>{ req });
        Test.stopTest();

        System.assertEquals(true, results[0].success);
        System.assertEquals(false, results[0].linked);
        System.assertEquals('Staged', results[0].message);
        System.assertNotEquals(null, results[0].pendingId);
    }

    @IsTest
    static void testFullLinkingFlow() {
        Account acc = getTestAccount();
        Id docId = createTestFile(acc.Id);
        Id matterId = createTestMatter(acc.Id);

        AdobeFAMatterFileLinkHandler.Request pdfReq = new AdobeFAMatterFileLinkHandler.Request();
        pdfReq.accountId = acc.Id;
        pdfReq.contentDocumentId = docId;
        AdobeFAMatterFileLinkHandler.link(new List<AdobeFAMatterFileLinkHandler.Request>{ pdfReq });

        AdobeFAMatterFileLinkHandler.Request matterReq = new AdobeFAMatterFileLinkHandler.Request();
        matterReq.accountId = acc.Id;
        matterReq.matterId = matterId;

        Test.startTest();
        List<AdobeFAMatterFileLinkHandler.Response> results =
            AdobeFAMatterFileLinkHandler.link(new List<AdobeFAMatterFileLinkHandler.Request>{ matterReq });
        Test.stopTest();

        System.assertEquals(true, results[0].linked);
        System.assertEquals('Linked', results[0].message);

        List<ContentDocumentLink> cdls = [
            SELECT Id FROM ContentDocumentLink WHERE LinkedEntityId = :matterId AND ContentDocumentId = :docId
        ];
        System.assertEquals(1, cdls.size());
    }

    @IsTest
    static void testDuplicateLinkPrevented() {
        Account acc = getTestAccount();
        Id docId = createTestFile(acc.Id);
        Id matterId = createTestMatter(acc.Id);

        insert new ContentDocumentLink(
            LinkedEntityId = matterId, ContentDocumentId = docId,
            ShareType = 'V', Visibility = 'InternalUsers'
        );

        AdobeFAMatterFileLinkHandler.Request pdfReq = new AdobeFAMatterFileLinkHandler.Request();
        pdfReq.accountId = acc.Id;
        pdfReq.contentDocumentId = docId;
        AdobeFAMatterFileLinkHandler.link(new List<AdobeFAMatterFileLinkHandler.Request>{ pdfReq });

        AdobeFAMatterFileLinkHandler.Request matterReq = new AdobeFAMatterFileLinkHandler.Request();
        matterReq.accountId = acc.Id;
        matterReq.matterId = matterId;

        Test.startTest();
        List<AdobeFAMatterFileLinkHandler.Response> results =
            AdobeFAMatterFileLinkHandler.link(new List<AdobeFAMatterFileLinkHandler.Request>{ matterReq });
        Test.stopTest();

        System.assertEquals(true, results[0].linked);

        List<ContentDocumentLink> cdls = [
            SELECT Id FROM ContentDocumentLink WHERE LinkedEntityId = :matterId AND ContentDocumentId = :docId
        ];
        System.assertEquals(1, cdls.size());
    }

    @IsTest
    static void testMissingAgreementId() {
        Account acc = new Account(LastName = 'No Agreement', RecordTypeId = PC_RECORD_TYPE_ID);
        insert acc;

        AdobeFAMatterFileLinkHandler.Request req = new AdobeFAMatterFileLinkHandler.Request();
        req.accountId = acc.Id;

        Test.startTest();
        List<AdobeFAMatterFileLinkHandler.Response> results =
            AdobeFAMatterFileLinkHandler.link(new List<AdobeFAMatterFileLinkHandler.Request>{ req });
        Test.stopTest();

        System.assertEquals(false, results[0].success);
        System.assert(results[0].message.contains('FA_Portal_AgreementId__c'));

        List<ErrorLog__c> logs = [SELECT Id FROM ErrorLog__c WHERE Class_Name__c = 'AdobeFAMatterFileLinkHandler'];
        System.assert(!logs.isEmpty());
    }

    @IsTest
    static void testNoAccountId() {
        AdobeFAMatterFileLinkHandler.Request req = new AdobeFAMatterFileLinkHandler.Request();

        Test.startTest();
        List<AdobeFAMatterFileLinkHandler.Response> results =
            AdobeFAMatterFileLinkHandler.link(new List<AdobeFAMatterFileLinkHandler.Request>{ req });
        Test.stopTest();

        System.assertEquals(false, results[0].success);
        System.assertEquals('Could not resolve AccountId.', results[0].message);

        List<ErrorLog__c> logs = [SELECT Id FROM ErrorLog__c WHERE Class_Name__c = 'AdobeFAMatterFileLinkHandler'];
        System.assert(!logs.isEmpty());
    }

    @IsTest
    static void testNullAndEmpty() {
        Test.startTest();
        System.assertEquals(0, AdobeFAMatterFileLinkHandler.link(null).size());
        System.assertEquals(0, AdobeFAMatterFileLinkHandler.link(new List<AdobeFAMatterFileLinkHandler.Request>()).size());
        Test.stopTest();
    }

    @IsTest
    static void testAccountResolutionFallbacks() {
        Account acc = getTestAccount();
        Id docId = createTestFile(acc.Id);

        AdobeFAMatterFileLinkHandler.Request req1 = new AdobeFAMatterFileLinkHandler.Request();
        req1.firstPublishLocationId = acc.Id;
        req1.contentDocumentId = docId;

        AdobeFAMatterFileLinkHandler.Request req2 = new AdobeFAMatterFileLinkHandler.Request();
        req2.contentDocumentId = docId;

        Test.startTest();
        List<AdobeFAMatterFileLinkHandler.Response> r1 =
            AdobeFAMatterFileLinkHandler.link(new List<AdobeFAMatterFileLinkHandler.Request>{ req1 });
        List<AdobeFAMatterFileLinkHandler.Response> r2 =
            AdobeFAMatterFileLinkHandler.link(new List<AdobeFAMatterFileLinkHandler.Request>{ req2 });
        Test.stopTest();

        System.assertEquals(true, r1[0].success);
        System.assertEquals(true, r2[0].success);
    }
}