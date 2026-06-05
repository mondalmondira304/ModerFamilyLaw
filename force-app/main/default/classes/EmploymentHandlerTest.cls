@isTest 
public class EmploymentHandlerTest {
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
        m.hire_date__c = Date.today();
        insert m;

        Employment__c e = new Employment__c();
        e.Name = 'Test Job';
        e.Related_Matter__c = m.Id;

        test.startTest();
        insert e;
        test.stopTest();

        Employment__c emp = [SELECT Id, Related_To__c FROM Employment__c WHERE Id = :e.Id];
        System.assertEquals(client.Id, emp.Related_To__c);
    }
}