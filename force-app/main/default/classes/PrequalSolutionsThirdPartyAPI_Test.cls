@IsTest
private class PrequalSolutionsThirdPartyAPI_Test {
    /** -------------------- Helpers -------------------- **/
    private static Account makeThirdParty() {
        Account tp = new Account(
            RecordTypeId = Schema.SObjectType.Account.getRecordTypeInfosByName().get('Person Account') != null ?
                Schema.SObjectType.Account.getRecordTypeInfosByName().get('Person Account').getRecordTypeId() : null,
            FirstName = 'Brook',
            LastName  = 'Byrd',
            PersonMailingStreet = '123 A St',
            PersonMailingCity   = 'Austin',
            State_A__c          = 'texas',
            PersonMailingPostalCode = '73301',
            Birthdate__c = Date.newInstance(1990,1,1),
            PersonMobilePhone = '5125550000',
            PersonEmail       = 'bb@test.com',
            Annual_household_income__c = 25000,
            Social_Security_Number__c  = '123456789'
        );
        insert tp;
        return tp;
    }
    private static Account makeParent(Decimal quoted) {
        Account p = new Account(
            Name='Parent',
            Quoted_Retainer__c = quoted
        );
        insert p;
        return p;
    }

    // Generic single-response mock
    private class OneShotMock implements HttpCalloutMock {
        Integer sc; String body;
        OneShotMock(Integer code, String b){ sc=code; body=b; }
        public HTTPResponse respond(HTTPRequest req){
            HttpResponse r = new HttpResponse();
            r.setStatusCode(sc); r.setBody(body);
            return r;
        }
    }

    // JSON builders
    private static String body200_passSilver() {
        return '{"api":{"response":{"code":200,"data":{"reports":{"individual":[{'
            + '"temporary_shareable_link":"http://tmp/link","result_status_type":"Success",'
            + '"decisioning":[{"criteria_set_name":"Silver - 50% Retainer","result":"pass"}],'
            + '"details":{"normalized":{"CREDIT_FROZEN_STATUS":{"EquifaxIndicator":"false","ExperianIndicator":"false","TransUnionIndicator":"false"},'
            + '"CREDIT_FILE":{"ResultStatusType":"Hit"}}}'
            + '}]}}}}}';
    }
    private static String body200_notQualified() {
        return '{"api":{"response":{"code":200,"data":{"reports":{"individual":[{'
            + '"temporary_shareable_link":"http://tmp/link2","result_status_type":"Success",'
            + '"decisioning":[{"criteria_set_name":"Gold - 0% Retainer","result":"fail"},'
            + '               {"criteria_set_name":"Silver - 50% Retainer","result":"fail"},'
            + '               {"criteria_set_name":"Bronze - 80% Retainer","result":"fail"}],'
            + '"details":{"normalized":{"CREDIT_FROZEN_STATUS":{"EquifaxIndicator":"false","ExperianIndicator":"false","TransUnionIndicator":"false"},'
            + '"CREDIT_FILE":{"ResultStatusType":"Hit"}}}'
            + '}]}}}}}';
    }
private static String body200_creditFrozen_byIndicator() {
    
    return '{"api":{"response":{"code":200,"data":{"reports":{"individual":[{'
        + '"temporary_shareable_link":"http://tmp/link3",'
        + '"result_status_type":"Success",'
        + '"decisioning":[{"criteria_set_name":"Gold - 0% Retainer","result":"fail"},'
        + '               {"criteria_set_name":"Silver - 50% Retainer","result":"fail"},'
        + '               {"criteria_set_name":"Bronze - 80% Retainer","result":"fail"}],'
        + '"details":{"normalized":{'
        + '  "CREDIT_FROZEN_STATUS":{"EquifaxIndicator":"false","ExperianIndicator":"true","TransUnionIndicator":"false"},'
        + '  "CREDIT_FILE":{"ResultStatusType":"NoFileReturnedCreditFreeze"}'
        + '}}'
        + '}]}}}}}';
}


    private static String body200_noFileReturn() {
        return '{"api":{"response":{"code":200,"data":{"reports":{"individual":[{'
            + '"temporary_shareable_link":"http://tmp/link4","result_status_type":"NoFileReturnedNoHit",'
            + '"decisioning":[{"criteria_set_name":"Gold - 0% Retainer","result":"fail"}],'
            + '"details":{"normalized":{"CREDIT_FROZEN_STATUS":{"EquifaxIndicator":"false","ExperianIndicator":"false","TransUnionIndicator":"false"},'
            + '"CREDIT_FILE":{"ResultStatusType":"NoFileReturned"}}}'
            + '}]}}}}}';
    }
    private static String body400_validation() {
        return '{"api":{"response":{"code":400,"errors":{"messages":{"ssn":["Invalid format"],"zip":["Bad zip"]}}}}}';
    }

    private static void setOverrides() {
        PrequalSolutionsThirdPartyAPI.tvNamedCredential = 'prequalNC';
        PrequalSolutionsThirdPartyAPI.tvScenario        = 'demo';
    }


    @IsTest static void t200_silver_pass_setsDiscountAndLink() {
        setOverrides();
        Account tp = makeThirdParty();
        Account p  = makeParent(2500);

        Test.setMock(HttpCalloutMock.class, new OneShotMock(200, body200_passSilver()));
        Test.startTest();
        System.enqueueJob(new PrequalSolutionsThirdPartyAPI.APIIntegrationJob(tp.Id, p.Id));
        Test.stopTest();

        p = [SELECT Credit_Decision__c, Credit_Check_Complete__c, Credit_Report_Link__c,
                    Quoted_Retainer__c, Quoted_Retainer_Amount__c, Credit_Message__c
             FROM Account WHERE Id=:p.Id];
        System.assertEquals('Silver - 50% Retainer', p.Credit_Decision__c);
        System.assertEquals(true, p.Credit_Check_Complete__c);
        System.assert(p.Credit_Report_Link__c.startsWith('http://tmp/'));
        System.assertEquals(1250, p.Quoted_Retainer_Amount__c); // 2500 * 0.5
        System.assertEquals(null, p.Credit_Message__c);
    }

    @IsTest static void t200_notQualified_setsFullWithMessage() {
        setOverrides();
        Account tp = makeThirdParty();
        Account p  = makeParent(3000);

        Test.setMock(HttpCalloutMock.class, new OneShotMock(200, body200_notQualified()));
        Test.startTest();
        System.enqueueJob(new PrequalSolutionsThirdPartyAPI.APIIntegrationJob(tp.Id, p.Id));
        Test.stopTest();

        p = [SELECT Credit_Decision__c, Credit_Message__c, Quoted_Retainer_Amount__c
             FROM Account WHERE Id=:p.Id];
        System.assertEquals('Full Retainer', p.Credit_Decision__c);
        System.assertEquals('Not Qualified by criteria.', p.Credit_Message__c);
        System.assertEquals(3000, p.Quoted_Retainer_Amount__c);
    }

  @IsTest
static void t200_creditFrozen_setsFrozenIncomplete() {
    setOverrides();
    Account tp = makeThirdParty();
    Account p  = makeParent(1800);

    Test.setMock(HttpCalloutMock.class, new OneShotMock(200, body200_creditFrozen_byIndicator()));

    Test.startTest();
    System.enqueueJob(new PrequalSolutionsThirdPartyAPI.APIIntegrationJob(tp.Id, p.Id));
    Test.stopTest();

    
    p = [
        SELECT Credit_Check_Complete__c
        FROM Account
        WHERE Id = :p.Id
    ];

    System.assertEquals(
        false,
        p.Credit_Check_Complete__c,
        'Frozen case should leave Credit_Check_Complete__c = false'
    );
}

    @IsTest static void t200_noFileReturn_setsFullWithNoHitMsg() {
        setOverrides();
        Account tp = makeThirdParty();
        Account p  = makeParent(2200);

        Test.setMock(HttpCalloutMock.class, new OneShotMock(200, body200_noFileReturn()));
        Test.startTest();
        System.enqueueJob(new PrequalSolutionsThirdPartyAPI.APIIntegrationJob(tp.Id, p.Id));
        Test.stopTest();

        p = [SELECT Credit_Decision__c, Credit_Check_Complete__c, Credit_Message__c,
                    Quoted_Retainer_Amount__c
             FROM Account WHERE Id=:p.Id];
        System.assertEquals('Full Retainer', p.Credit_Decision__c);
        System.assertEquals(true, p.Credit_Check_Complete__c);
        System.assertEquals('No credit file was returned (No Hit).', p.Credit_Message__c);
        System.assertEquals(2200, p.Quoted_Retainer_Amount__c);
    }

    @IsTest static void t400_validation_persistsMessagesAndFailedLink() {
        setOverrides();
        Account tp = makeThirdParty();
        Account p  = makeParent(1500);

        Test.setMock(HttpCalloutMock.class, new OneShotMock(400, body400_validation()));
        Test.startTest();
        System.enqueueJob(new PrequalSolutionsThirdPartyAPI.APIIntegrationJob(tp.Id, p.Id));
        Test.stopTest();

        p = [SELECT Credit_Decision__c, Credit_Check_Complete__c, Credit_Report_Link__c,
                    Credit_Message__c, Quoted_Retainer_Amount__c
             FROM Account WHERE Id=:p.Id];
        System.assertEquals('Full Retainer', p.Credit_Decision__c);
        System.assertEquals(false, p.Credit_Check_Complete__c);
        System.assertEquals('Failed-400', p.Credit_Report_Link__c);
        System.assert(p.Credit_Message__c != null && p.Credit_Message__c.contains('ssn'));
        System.assertEquals(1500, p.Quoted_Retainer_Amount__c);
    }
}