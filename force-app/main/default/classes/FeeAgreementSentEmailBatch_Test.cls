@isTest
public class FeeAgreementSentEmailBatch_Test {
    
    @testSetup
    public static void testSetUp(){
        Account acc = new Account(
            ICI_Attorney_A__c = userInfo.getUserId(),
            firstname = 'test',
            LastName = 'test',
            Fee_Agreement_Sent__c = system.today()-3,
            Consultation_Status__c = 'Fee Agreement Pending'          
        );
        insert acc;
    }
    
    @isTest
    private static void testMethod1(){
        test.startTest();
        FeeAgreementSentEmailBatch bch = new FeeAgreementSentEmailBatch();
        system.schedule('test','0 0 2 * * ?',bch);
        test.stopTest();
    }
    
}