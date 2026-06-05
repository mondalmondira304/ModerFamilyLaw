@isTest(SeeAllData=true)
private class AdobeAgreementFileSaver_Test {

    private static Id getOrCreateTestAccountId() {
        List<Account> accounts = [SELECT Id FROM Account WHERE IsPersonAccount = true LIMIT 1];
        if (accounts.isEmpty()) {
            accounts = [SELECT Id FROM Account LIMIT 1];
        }
        if (!accounts.isEmpty()) {
            return accounts[0].Id;
        }

        Account a = new Account(Name = 'AdobeAgreementFileSaver_Test');
        insert a;
        return a.Id;
    }

    @isTest
    static void testSuccessfulSave() {
        Id accId = getOrCreateTestAccountId();

        Blob pdfBlob = Blob.valueOf('Mock PDF Content');

        Test.startTest();
        AdobeAgreementFileSaver.saveFinalPdf(pdfBlob, accId, 'AGR123', 'Test Agreement');
        Test.stopTest();

        List<ContentVersion> cvList = [
            SELECT Title, PathOnClient, ContentDocumentId, FirstPublishLocationId
            FROM ContentVersion
            WHERE FirstPublishLocationId = :accId
            AND Title = 'Test Agreement'
            ORDER BY CreatedDate DESC
            LIMIT 1
        ];

        System.assertEquals(1, cvList.size(), 'Expected a ContentVersion published to the Account');
        System.assertEquals('Test Agreement', cvList[0].Title);
        System.assertEquals('Test Agreement.pdf', cvList[0].PathOnClient);
        System.assertNotEquals(null, cvList[0].ContentDocumentId, 'ContentDocumentId should be set after insert');
        System.assertEquals(accId, cvList[0].FirstPublishLocationId);
    }

    @isTest
    static void testMissingAccountId() {
        Blob pdfBlob = Blob.valueOf('Mock PDF Content');

        Test.startTest();
        try {
            AdobeAgreementFileSaver.saveFinalPdf(pdfBlob, null, 'AGR123', 'Test');
            System.assert(false, 'Should throw exception');
        } catch (AdobeAgreementFileSaver.FileSaveException ex) {
            System.assert(ex.getMessage().contains('AccountId is required'), ex.getMessage());
        }
        Test.stopTest();
    }

    @isTest
    static void testMissingPdfBlob_Null() {
        Id accId = getOrCreateTestAccountId();

        Test.startTest();
        try {
            AdobeAgreementFileSaver.saveFinalPdf(null, accId, 'AGR123', 'Test');
            System.assert(false, 'Should throw exception');
        } catch (AdobeAgreementFileSaver.FileSaveException ex) {
            System.assert(ex.getMessage().contains('PDF Blob is null'), ex.getMessage());
        }
        Test.stopTest();
    }

    @isTest
    static void testMissingPdfBlob_Empty() {
        Id accId = getOrCreateTestAccountId();

        Blob emptyBlob = Blob.valueOf('');

        Test.startTest();
        try {
            AdobeAgreementFileSaver.saveFinalPdf(emptyBlob, accId, 'AGR123', 'Test');
            System.assert(false, 'Should throw exception');
        } catch (AdobeAgreementFileSaver.FileSaveException ex) {
            System.assert(ex.getMessage().contains('PDF Blob is null or empty'), ex.getMessage());
        }
        Test.stopTest();
    }

    @isTest
    static void testDefaultTitleWhenAgreementNameNull() {
        Id accId = getOrCreateTestAccountId();
        Blob pdfBlob = Blob.valueOf('Mock PDF Content');

        Test.startTest();
        AdobeAgreementFileSaver.saveFinalPdf(pdfBlob, accId, 'AGR123', null);
        Test.stopTest();

        ContentVersion cv = [
            SELECT Title, PathOnClient
            FROM ContentVersion
            WHERE FirstPublishLocationId = :accId
            AND Title = 'Fee Agreement'
            ORDER BY CreatedDate DESC
            LIMIT 1
        ];

        System.assertEquals('Fee Agreement', cv.Title);
        System.assertEquals('Fee Agreement.pdf', cv.PathOnClient);
    }

    @isTest
    static void testDefaultTitleWhenAgreementNameBlank() {
        Id accId = getOrCreateTestAccountId();
        Blob pdfBlob = Blob.valueOf('Mock PDF Content');

        Test.startTest();
        AdobeAgreementFileSaver.saveFinalPdf(pdfBlob, accId, 'AGR123', '   ');
        Test.stopTest();

        ContentVersion cv = [
            SELECT Title, PathOnClient
            FROM ContentVersion
            WHERE FirstPublishLocationId = :accId
            AND Title = 'Fee Agreement'
            ORDER BY CreatedDate DESC
            LIMIT 1
        ];

        System.assertEquals('Fee Agreement', cv.Title);
        System.assertEquals('Fee Agreement.pdf', cv.PathOnClient);
    }

    @isTest
    static void testPdfExtensionHandling_LowercaseAlreadyPresent() {
        Id accId = getOrCreateTestAccountId();
        Blob pdfBlob = Blob.valueOf('Mock PDF Content');

        Test.startTest();
        AdobeAgreementFileSaver.saveFinalPdf(pdfBlob, accId, 'AGR123', 'Test Agreement.pdf');
        Test.stopTest();

        ContentVersion cv = [
            SELECT PathOnClient
            FROM ContentVersion
            WHERE FirstPublishLocationId = :accId
            ORDER BY CreatedDate DESC
            LIMIT 1
        ];

        System.assertEquals('Test Agreement.pdf', cv.PathOnClient);
        System.assertNotEquals('Test Agreement.pdf.pdf', cv.PathOnClient);
    }

    @isTest
    static void testPdfExtensionHandling_UppercasePDF_NoDoubleAppend() {
        Id accId = getOrCreateTestAccountId();
        Blob pdfBlob = Blob.valueOf('Mock PDF Content');

        Test.startTest();
        AdobeAgreementFileSaver.saveFinalPdf(pdfBlob, accId, 'AGR123', 'My Agreement.PDF');
        Test.stopTest();

        ContentVersion cv = [
            SELECT PathOnClient
            FROM ContentVersion
            WHERE FirstPublishLocationId = :accId
            ORDER BY CreatedDate DESC
            LIMIT 1
        ];

        System.assertEquals('My Agreement.PDF', cv.PathOnClient, 'Should not append .pdf when .PDF already present');
        System.assert(cv.PathOnClient.toLowerCase().endsWith('.pdf'), 'Should end in .pdf (case-insensitive)');
    }

    @isTest
    static void testCatchBlock_DmlFailure_TitleTooLong() {
        Id accId = getOrCreateTestAccountId();
        Blob pdfBlob = Blob.valueOf('Mock PDF Content');

        String longTitle = '';
        for (Integer i = 0; i < 300; i++) longTitle += 'A';

        Test.startTest();
        try {
            AdobeAgreementFileSaver.saveFinalPdf(pdfBlob, accId, 'AGR123', longTitle);
            System.assert(false, 'Expected FileSaveException due to Title length / DML failure');
        } catch (AdobeAgreementFileSaver.FileSaveException ex) {
            System.assert(
                ex.getMessage().startsWith('Failed to save final PDF:'),
                'Expected wrapped FileSaveException. Actual: ' + ex.getMessage()
            );
        }
        Test.stopTest();
    }
}