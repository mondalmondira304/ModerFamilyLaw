@isTest
public with sharing class ContactTriggerHandlerTest {
    
    @isTest
    private static void contactTriggerTest(){
        Contact c = new Contact();
        c.FirstName = 'testing';
        c.LastName = 'testing';
        c.Email = 'test@test.net';
        insert c;
    }
}