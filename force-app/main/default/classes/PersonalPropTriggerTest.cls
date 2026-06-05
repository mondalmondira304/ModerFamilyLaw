@isTest 
public class PersonalPropTriggerTest {
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

        Furniture_Personal_Property__c prop = new Furniture_Personal_Property__c();
        prop.Name = 'Test Personal Property';
        prop.Related_Matter__c = m.Id;

        test.startTest();
        insert prop;
        test.stopTest();

        Furniture_Personal_Property__c p = [SELECT Id, Related_Account__c FROM Furniture_Personal_Property__c WHERE Id = :prop.Id];
        System.assertEquals(client.Id, p.Related_Account__c);
    }
}