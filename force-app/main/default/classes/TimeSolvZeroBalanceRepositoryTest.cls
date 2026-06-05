@IsTest
private class TimeSolvZeroBalanceRepositoryTest {

    private static final String TASK_SUBJECT = 'Zero Balance Test Task';

    private static Id getPersonAccountRecordTypeId() {
        return [SELECT Id FROM RecordType WHERE SObjectType = 'Account' AND IsPersonType = true LIMIT 1].Id;
    }

    private static Account createTestAccount() {
        Account acc = new Account(RecordTypeId = getPersonAccountRecordTypeId(), LastName = 'Repo Test',
            PersonEmail = 'repo@test.com', Responsible_Attorney__c = UserInfo.getUserId(),
            Timesolv_TrustAccount_Balance__c = 0, Timesolv_TrustAccount_Replenish_Below__c = 100,
            Timesolv_TrustAccount_Replenish_To__c = 500);
        insert acc;
        return [SELECT Id, PersonContactId, Responsible_Attorney__c FROM Account WHERE Id = :acc.Id];
    }

    @IsTest
    static void testGetRecentlyNotifiedAccountIds() {
        Account acc = createTestAccount();
        insert new Task(Subject = TASK_SUBJECT, WhatId = acc.Id, WhoId = acc.PersonContactId,
            OwnerId = UserInfo.getUserId(), Status = 'Completed', Priority = 'Normal');

        Test.startTest();
        TimeSolvZeroBalanceRepository repo = new TimeSolvZeroBalanceRepository();
        Set<Id> result = repo.getRecentlyNotifiedAccountIds(TASK_SUBJECT, System.now().addDays(-1));
        Set<Id> empty = repo.getRecentlyNotifiedAccountIds(TASK_SUBJECT, System.now().addDays(1));
        Test.stopTest();

        System.assert(result.contains(acc.Id));
        System.assert(empty.isEmpty());
    }

    @IsTest
    static void testGetActiveUsersById() {
        TimeSolvZeroBalanceRepository repo = new TimeSolvZeroBalanceRepository();

        Test.startTest();
        Map<Id, User> result = repo.getActiveUsersById(new Set<Id>{ UserInfo.getUserId() });
        Map<Id, User> emptyResult = repo.getActiveUsersById(new Set<Id>());
        Map<Id, User> nullResult = repo.getActiveUsersById(null);
        Test.stopTest();

        System.assert(result.containsKey(UserInfo.getUserId()));
        System.assert(emptyResult.isEmpty());
        System.assert(nullResult.isEmpty());
    }

    @IsTest
    static void testGetSuppressionTasksByAccountId() {
        Account acc = createTestAccount();
        insert new Task(Subject = TASK_SUBJECT, WhatId = acc.Id, WhoId = acc.PersonContactId,
            OwnerId = UserInfo.getUserId(), Status = 'Completed', Priority = 'Normal');
        insert new Task(Subject = TASK_SUBJECT, WhatId = acc.Id, WhoId = acc.PersonContactId,
            OwnerId = UserInfo.getUserId(), Status = 'Completed', Priority = 'Normal');
        insert new Task(Subject = TASK_SUBJECT, WhatId = acc.Id, WhoId = acc.PersonContactId,
            OwnerId = UserInfo.getUserId(), Status = 'Completed', Priority = 'Normal');

        Test.startTest();
        TimeSolvZeroBalanceRepository repo = new TimeSolvZeroBalanceRepository();
        Map<Id, List<Task>> result = repo.getSuppressionTasksByAccountId(new Set<Id>{ acc.Id }, TASK_SUBJECT);
        Map<Id, List<Task>> emptyResult = repo.getSuppressionTasksByAccountId(null, TASK_SUBJECT);
        Test.stopTest();

        System.assertEquals(2, result.get(acc.Id).size(), 'Should cap at 2 tasks.');
        System.assert(emptyResult.isEmpty());
    }

    @IsTest
    static void testGetOrgWideEmailAddressId() {
        TimeSolvZeroBalanceRepository repo = new TimeSolvZeroBalanceRepository();
        Test.startTest();
        Id result = repo.getOrgWideEmailAddressId('nonexistent@doesnotexist.invalid');
        Test.stopTest();
        System.assertEquals(null, result);
    }

    @IsTest
    static void testGetEmailTemplateIds() {
        TimeSolvZeroBalanceRepository repo = new TimeSolvZeroBalanceRepository();
        Test.startTest();
        Map<String, Id> result = repo.getEmailTemplateIds(new Set<String>{ 'Nonexistent_Template_XYZ' });
        Map<String, Id> emptyResult = repo.getEmailTemplateIds(null);
        Test.stopTest();
        System.assert(result.isEmpty());
        System.assert(emptyResult.isEmpty());
    }

    @IsTest
    static void testInsertSuppressionTasks() {
        Account acc = createTestAccount();
        Task t = new Task(Subject = TASK_SUBJECT, WhatId = acc.Id, WhoId = acc.PersonContactId,
            OwnerId = UserInfo.getUserId(), Status = 'Completed', Priority = 'Normal');

        Test.startTest();
        TimeSolvZeroBalanceRepository repo = new TimeSolvZeroBalanceRepository();
        Database.SaveResult[] results = repo.insertSuppressionTasks(new List<Task>{ t });
        Database.SaveResult[] emptyResults = repo.insertSuppressionTasks(null);
        Test.stopTest();

        System.assert(results[0].isSuccess());
        System.assert(emptyResults.isEmpty());
    }

    @IsTest
    static void testGetCandidateAccountsEmptyExclusions() {
        TimeSolvZeroBalanceConfig.setTestConfig(50, 7, TASK_SUBJECT, 'test@test.com',
            'First_Template', 'Second_Template', 'Excluded Prefix');
        TimeSolvZeroBalanceConfig config = TimeSolvZeroBalanceConfig.getActive();

        Test.startTest();
        TimeSolvZeroBalanceRepository repo = new TimeSolvZeroBalanceRepository();
        Database.QueryLocator ql = repo.getCandidateAccounts(config, new Set<Id>());
        Database.QueryLocator ql2 = repo.getCandidateAccounts(config, null);
        Test.stopTest();

        System.assertNotEquals(null, ql);
        System.assertNotEquals(null, ql2);
        TimeSolvZeroBalanceConfig.clearTestConfig();
    }

    @IsTest
    static void testGetCandidateAccountsWithExclusions() {
        TimeSolvZeroBalanceConfig.setTestConfig(50, 7, TASK_SUBJECT, 'test@test.com',
            'First_Template', 'Second_Template', 'Excluded Prefix');
        TimeSolvZeroBalanceConfig config = TimeSolvZeroBalanceConfig.getActive();
        Account acc = createTestAccount();

        Test.startTest();
        TimeSolvZeroBalanceRepository repo = new TimeSolvZeroBalanceRepository();
        Database.QueryLocator ql = repo.getCandidateAccounts(config, new Set<Id>{ acc.Id });
        Test.stopTest();

        System.assertNotEquals(null, ql);
        TimeSolvZeroBalanceConfig.clearTestConfig();
    }
}