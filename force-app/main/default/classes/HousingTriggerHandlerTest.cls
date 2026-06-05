@isTest 
public class HousingTriggerHandlerTest {
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

        Housing__c house = new Housing__c();
        house.Name = 'Test House';
        house.Related_Matter__c = m.Id;

        test.startTest();
        insert house;
        test.stopTest();
        Housing__c h = [SELECT Id, Client__c FROM Housing__c WHERE Id = :house.Id];
        System.assertEquals(client.Id, h.Client__c);
    }
}