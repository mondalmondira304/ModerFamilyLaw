@isTest
private class CG_TaskAutoDateChangeTest {
    public static Id prsnAccountRecTypeId = Schema.SObjectType.Account.getRecordTypeInfosByDeveloperName().get('PersonAccount').getRecordTypeId();
    static testMethod void getDayOfWeek() {
        Date d = Date.newInstance(2020, 8, 12);

        Integer day = CG_DateChangeUtils.getDayOfWeek(d);

        System.assertEquals(3, day);
    }
    
    static TestMethod void getHolidayDate() {
        //Test Thanksgiving
        Integer day = 4; //Thursday
        Integer week = 4; //Fourth week of the month
        Integer Month = 11; //November
        Integer year = 2020;

        Date thanksgivingDate = CG_DateChangeUtils.getNthDayOfNthWeek(day, week, month, year);

        Date d = Date.newInstance(2020, 11, 26);
        System.assertEquals(thanksgivingDate, d);

        //getNthDayOfNthWeek(Integer day, Integer week, Integer month, Integer year)
    }

    static testMethod void getAllHolidays() {
        Map<String, Date> holidayMap = new Map<String, Date>();
        Date today = Date.newInstance(2020, 8, 12);

        holidayMap = CG_DateChangeUtils.getHolidayDates(today);

        System.assertEquals(Date.newInstance(2021, 1, 1), holidayMap.get('New Year'));
        System.assertEquals(Date.newInstance(2021, 1, 18), holidayMap.get('MLK Day'));
        System.assertEquals(Date.newInstance(2021, 2, 15), holidayMap.get('Wash-Lin Day'));
        System.assertEquals(Date.newInstance(2021, 5, 31), holidayMap.get('Memorial Day'));
        System.assertEquals(Date.newInstance(2021, 7, 4), holidayMap.get('Independence Day'));
        System.assertEquals(Date.newInstance(2020, 9, 7), holidayMap.get('Labor Day'));
        System.assertEquals(Date.newInstance(2020, 10, 12), holidayMap.get('Columbus Day'));
        System.assertEquals(Date.newInstance(2020, 11, 26), holidayMap.get('Thanksgiving Day'));
        System.assertEquals(Date.newInstance(2020, 12, 25), holidayMap.get('Christmas Day'));
    }

    static testMethod void getValidDueDateAfterLinkedDate() {
        Date linkedDate = Date.newInstance(2020, 12, 30);
        Integer dayChange = 2;
        Date expectedDate = Date.newInstance(2021, 1, 4);

        Date dueDate = CG_DateChangeUtils.getValidDate(linkedDate, dayChange);

        System.assertEquals(expectedDate, dueDate);
    }

    static testMethod void getValidDueDateBeforeLinkedDate() {
        Date linkedDate = Date.newInstance(2021, 1, 3);
        Integer dayChange = -2;
        Date expectedDate = Date.newInstance(2020, 12, 31);

        Date dueDate = CG_DateChangeUtils.getValidDate(linkedDate, dayChange);

        System.assertEquals(expectedDate, dueDate);
    }

    static testMethod void getValidDueDateNoPush() {
        Date linkedDate = Date.newInstance(2021, 1, 3);
        Integer dayChange = 0;
        Date expectedDate = Date.newInstance(2021, 1, 4);

        Date dueDate = CG_DateChangeUtils.getValidDate(linkedDate, dayChange);

        System.assertEquals(expectedDate, dueDate);
    }

    static testMethod void taskCreatedWithValidDate() {

        Auto_Date_Change_Config__c config = new Auto_Date_Change_Config__c();
        config.Active__c = true;
        config.Tracked_Fields_1__c = 'Hire_Date__c';
        insert config;
        
        /*Contact c = new Contact();
        c.FirstName = 'Test';
        c.LastName = 'Contact';
        c.Email = 'test@contact.com';
        insert c; */

        Account c = new Account(); 
        c.RecordTypeid=prsnAccountRecTypeId;
        c.FirstName = 'Test';
        c.LastName = 'Contact';
        c.personemail = 'test@contact.com';
        insert c;
        
        Jurisdiction__c juri = new Jurisdiction__c();
        juri.name = 'Test Juri Name';
        insert juri;
 
        MFL_Office__c officeMFL = new MFL_Office__c();
        officeMFL.name = 'Test Office Name';
        insert officeMFL;
        
        
        Matters__c m = new Matters__c();
        m.Name = 'Test Matter';
        m.Client_Name__c = c.id;
        m.Hire_Date__c = Date.newInstance(2020, 1, 1);
        m.Jurisdiction__c = juri.id;
        m.MFL_Office__c = officeMFL.id;
        m.Case_Type__c = 'Criminal';
        insert m;

        Task t = new Task();
        t.Subject = 'Test Task';
        t.WhatId = m.Id;
        t.Linked_Date__c = 'Hire_Date__c';
        t.Date_Push__c = 40;
        insert t;

        Task newTask = [SELECT id, ActivityDate FROM Task WHERE id = :t.Id];

        System.assertEquals(Date.newInstance(2020, 2, 10), newTask.ActivityDate);
    }

    static testMethod void taskCreatedWithInvalidDate() {

        Auto_Date_Change_Config__c config = new Auto_Date_Change_Config__c();
        config.Active__c = true;
        config.Tracked_Fields_1__c = 'Hire_Date__c, New_Client_Questionnaire_Due_Date__c, Service_Date__c, Client_Financial_Disclosures_Due_Date__c, OP_Financial_Disclosures_Due_Date__c, OP_Compliant_Financial_Disclosures_Date__c,OP_Discovery_Response_Received_Date__c';
        config.Tracked_Fields_2__c = 'OP_Financial_Disclosures_Filed_Date__c, OP_Discovery_Response_Due_Date__c,Discovery_Response_Due_Date__c,ISC_Date__c,Temporary_Order_Hearing_Date__c,Settlement_Offer_Extend_Date__c,Mediation_Set_Deadline__c,Agreed_Mediation_Date__c,';
        config.Tracked_Fields_3__c = 'OP_Expert_Disclosure_Date__c,Final_Orders_Hearing_Date__c,';
        insert config;
        
        /*Contact c = new Contact();
        c.FirstName = 'Test';
        c.LastName = 'Contact';
        c.Email = 'test@contact.com';
        insert c;*/
        
        Account c = new Account(); 
        c.RecordTypeid=prsnAccountRecTypeId;
        c.FirstName = 'Test';
        c.LastName = 'Contact';
        c.personemail = 'test@contact.com';
        insert c;        

        Jurisdiction__c juri = new Jurisdiction__c();
        juri.name = 'Test Juri Name';
        insert juri;
 
        MFL_Office__c officeMFL = new MFL_Office__c();
        officeMFL.name = 'Test Office Name';
        insert officeMFL;
        
        
        Matters__c m = new Matters__c();
        m.Name = 'Test Matter';
        m.Client_Name__c = c.id;
        m.Hire_Date__c = Date.newInstance(2021, 1, 3);
        m.Jurisdiction__c = juri.id;
        m.MFL_Office__c = officeMFL.id;
        m.Case_Type__c = 'Criminal';
        insert m;

        Task t = new Task();
        t.Subject = 'Test Task';
        t.WhatId = m.Id;
        t.Linked_Date__c = 'Hire_Date__c';
        t.Date_Push__c = -2;
        insert t;

        Task newTask = [SELECT id, ActivityDate FROM Task WHERE id = :t.Id];

        System.assertEquals(Date.newInstance(2020, 12, 31), newTask.ActivityDate);
    }

    static testMethod void validationNotNeeded() {

        Auto_Date_Change_Config__c config = new Auto_Date_Change_Config__c();
        config.Active__c = true;
        config.Tracked_Fields_1__c = 'Hire_Date__c, New_Client_Questionnaire_Due_Date__c, Service_Date__c, Client_Financial_Disclosures_Due_Date__c, OP_Financial_Disclosures_Due_Date__c, OP_Compliant_Financial_Disclosures_Date__c,OP_Discovery_Response_Received_Date__c';
        config.Tracked_Fields_2__c = 'OP_Financial_Disclosures_Filed_Date__c, OP_Discovery_Response_Due_Date__c,Discovery_Response_Due_Date__c,ISC_Date__c,Temporary_Order_Hearing_Date__c,Settlement_Offer_Extend_Date__c,Mediation_Set_Deadline__c,Agreed_Mediation_Date__c';
        config.Tracked_Fields_3__c = 'OP_Expert_Disclosure_Date__c,Final_Orders_Hearing_Date__c';
        insert config;
        
        /*Contact c = new Contact();
        c.FirstName = 'Test';
        c.LastName = 'Contact';
        c.Email = 'test@contact.com';
        insert c; */

        Account c = new Account(); 
        c.RecordTypeid=prsnAccountRecTypeId;
        c.FirstName = 'Test';
        c.LastName = 'Contact';
        c.personemail = 'test@contact.com';
        insert c;  
        
        Jurisdiction__c juri = new Jurisdiction__c();
        juri.name = 'Test Juri Name';
        insert juri;
 
        MFL_Office__c officeMFL = new MFL_Office__c();
        officeMFL.name = 'Test Office Name';
        insert officeMFL;
                
        Matters__c m = new Matters__c();
        m.Name = 'Test Matter';
        m.Client_Name__c = c.id;
        m.Hire_Date__c = Date.newInstance(2020, 1, 3);
        m.Jurisdiction__c = juri.id;
        m.MFL_Office__c = officeMFL.id;
        m.Case_Type__c = 'Criminal';
        insert m;

        Task t = new Task();
        t.Subject = 'Test Task';
        t.WhatId = m.Id;
        t.ActivityDate = Date.newInstance(2020, 8, 14);
        insert t;

        Task newTask = [SELECT id, ActivityDate FROM Task WHERE id = :t.Id];

        System.assertEquals(Date.newInstance(2020, 8, 14), newTask.ActivityDate);
    }

    static testMethod void MatterDateUpdated() {
        Auto_Date_Change_Config__c config = new Auto_Date_Change_Config__c();
        config.Active__c = true;
        config.Tracked_Fields_1__c = 'Hire_Date__c, New_Client_Questionnaire_Due_Date__c, Service_Date__c, Client_Financial_Disclosures_Due_Date__c, OP_Financial_Disclosures_Due_Date__c, OP_Compliant_Financial_Disclosures_Date__c,OP_Discovery_Response_Received_Date__c';
        config.Tracked_Fields_2__c = 'OP_Financial_Disclosures_Filed_Date__c, OP_Discovery_Response_Due_Date__c,Discovery_Response_Due_Date__c,ISC_Date__c,Temporary_Order_Hearing_Date__c,Settlement_Offer_Extend_Date__c,Mediation_Set_Deadline__c,Agreed_Mediation_Date__c,';
        config.Tracked_Fields_3__c = 'OP_Expert_Disclosure_Date__c,Final_Orders_Hearing_Date__c,';
        insert config;
        
        /*Contact c = new Contact();
        c.FirstName = 'Test';
        c.LastName = 'Contact';
        c.Email = 'test@contact.com';
        insert c;*/
        
        Account c = new Account(); 
        c.RecordTypeid=prsnAccountRecTypeId;
        c.FirstName = 'Test';
        c.LastName = 'Contact';
        c.personemail = 'test@contact.com';
        insert c;  

        Jurisdiction__c juri = new Jurisdiction__c();
        juri.name = 'Test Juri Name';
        insert juri;
 
        MFL_Office__c officeMFL = new MFL_Office__c();
        officeMFL.name = 'Test Office Name';
        insert officeMFL;
        
        
        Matters__c m = new Matters__c();
        m.Name = 'Test Matter';
        m.Client_Name__c = c.id;
        m.Hire_Date__c = Date.newInstance(2020, 1, 3);
        m.Jurisdiction__c = juri.id;
        m.MFL_Office__c = officeMFL.id;
        m.Case_Type__c = 'Criminal';
        insert m;

        Task t = new Task();
        t.Subject = 'Test Task';
        t.WhatId = m.Id;
        t.Linked_Date__c = 'Hire_Date__c';
        t.Date_Push__c = 5;
        insert t;

        Task t1 = new Task();
        t1.Subject = 'Test Task 1';
        t1.WhatId = m.Id;
        t1.Linked_Date__c = 'Hire_Date__c';
        t1.Date_Push__c = -2;
        insert t1;

        Task t2 = new Task();
        t2.Subject = 'Test Task 2';
        t2.WhatId = m.Id;
        t2.Linked_Date__c = 'Final_Orders_Hearing_Date__c';
        t2.Date_Push__c = -2;
        insert t2;

        m.Hire_Date__c = Date.newInstance(2020, 4, 3);
        update m;

        t = [SELECT id, ActivityDate FROM Task WHERE id = :t.Id];
        t1 = [SELECT id, ActivityDate FROM Task WHERE id = :t1.Id];
        t2 = [SELECT id, ActivityDate FROM Task WHERE id = :t2.Id];
        
        System.assertEquals(Date.newInstance(2020, 4, 8), t.ActivityDate);
        System.assertEquals(Date.newInstance(2020, 4, 1), t1.ActivityDate);
        System.assertEquals(null, t2.ActivityDate);
    }
}