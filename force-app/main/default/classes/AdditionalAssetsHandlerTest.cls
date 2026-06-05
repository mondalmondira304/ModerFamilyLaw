@isTest 
public class AdditionalAssetsHandlerTest {
    public static Id prsnAccountRecTypeId = Schema.SObjectType.Account.getRecordTypeInfosByDeveloperName().get('PersonAccount').getRecordTypeId();
    @isTest
    private static void testClientStamping() {
        MFL_Office__c o = new MFL_Office__c();
        o.Name = 'Test Office';
        insert o;

        Account client = new Account();
        client.RecordTypeId = prsnAccountRecTypeId;
        client.firstName = 'Test';
        client.lastName = 'Client';
        client.PersonEmail = 'test@test.com';        
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

        Additional_Asset__c a = new Additional_Asset__c();
        a.Name = 'Test Additional Asset';
        a.Related_Matter__c = m.Id;

        test.startTest();
        insert a;
        test.stopTest();

        Additional_Asset__c asset = [SELECT Id, Client__c FROM Additional_Asset__c WHERE Id = :a.Id];
        System.assertEquals(client.Id, asset.Client__c);
    }
}