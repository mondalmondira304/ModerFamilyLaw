@isTest 
public class RetirementAccountHandlerTest {
    public static Id prsnAccountRecTypeId = Schema.SObjectType.Account.getRecordTypeInfosByDeveloperName().get('PersonAccount').getRecordTypeId();
    
    @isTest
    private static void testClientStamping() {
        MFL_Office__c o = new MFL_Office__c();
        o.Name = 'Test Office';
        insert o;

        Account client = new Account();
        client.firstName = 'Test';
        client.lastName = 'Client';
        client.PersonEmail = 'test@test.com';
        client.RecordTypeId = prsnAccountRecTypeId;
        insert client;

        Matters__c m = new Matters__c();
        m.Name = 'Test';
        m.MFL_Office__c = o.Id;
        m.Matter_ID_Client__c = '1111';
        m.Matter_ID_Matter__c = '123';
        m.Client_Name__c = client.Id;
        m.case_type__c = 'Adoption';
        m.hire_date__c = Date.today();
        insert m;

        Retirement_Account__c acct = new Retirement_Account__c();
        acct.Name = 'Test Retirement Acct';
        acct.Related_Matter__c = m.Id;

        test.startTest();
        insert acct;
        test.stopTest();

        Retirement_Account__c a = [SELECT Id, Client__c FROM Retirement_Account__c WHERE Id = :acct.Id];
        System.assertEquals(client.Id, a.Client__c);
    }
}