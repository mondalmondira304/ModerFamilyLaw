/**
 * @description Repository layer for Zero Balance notification queries and DML.
 *
 * @author Sanders
 */
public without sharing class TimeSolvZeroBalanceRepository {

    /**
     * @description Returns Account Ids with a recent suppression Task.
     * @param taskSubject Suppression Task subject.
     * @param thresholdDT Accounts with a Task on/after this datetime are excluded from the batch candidate set.
     * @return Set of Account Ids.
     */
    public Set<Id> getRecentlyNotifiedAccountIds(String taskSubject, Datetime thresholdDT) {
        Set<Id> accountIds = new Set<Id>();

        for (Task t : [
            SELECT WhatId
              FROM Task
             WHERE Subject = :taskSubject
               AND CreatedDate >= :thresholdDT
               AND WhatId != null
        ]) {
            accountIds.add(t.WhatId);
        }

        return accountIds;
    }

    /**
     * @description Returns the candidate Account query locator.
     * @param config Active configuration.
     * @param recentlyNotifiedAccountIds Accounts already notified within the recent threshold.
     * @return QueryLocator for batch start.
     */
    public Database.QueryLocator getCandidateAccounts(
        TimeSolvZeroBalanceConfig config,
        Set<Id> recentlyNotifiedAccountIds
    ) {
        String excludedPattern = config.excludedAgreementNamePrefix + '%';

        if (recentlyNotifiedAccountIds == null || recentlyNotifiedAccountIds.isEmpty()) {
            return Database.getQueryLocator([
                SELECT Id,
                       PersonContactId,
                       PersonEmail,
                       Responsible_Attorney__c,
                       Timesolv_TrustAccount_Balance__c,
                       Timesolv_TrustAccount_Replenish_Below__c,
                       Timesolv_TrustAccount_Replenish_To__c
                  FROM Account
                 WHERE Id IN (
                        SELECT echosign_dev1__Account__c
                          FROM echosign_dev1__SIGN_Agreement__c
                         WHERE echosign_dev1__Status__c = 'Signed'
                           AND (NOT (Name LIKE :excludedPattern))
                 )
                   AND Timesolv_TrustAccount_Replenish_Below__c > 0
                   AND Timesolv_TrustAccount_Replenish_To__c > 0
                   AND (
                        Timesolv_TrustAccount_Balance__c = 0
                        OR Timesolv_TrustAccount_Balance__c = null
                   )
            ]);
        }

        return Database.getQueryLocator([
            SELECT Id,
                   PersonContactId,
                   PersonEmail,
                   Responsible_Attorney__c,
                   Timesolv_TrustAccount_Balance__c,
                   Timesolv_TrustAccount_Replenish_Below__c,
                   Timesolv_TrustAccount_Replenish_To__c
              FROM Account
             WHERE Id IN (
                    SELECT echosign_dev1__Account__c
                      FROM echosign_dev1__SIGN_Agreement__c
                     WHERE echosign_dev1__Status__c = 'Signed'
                       AND (NOT (Name LIKE :excludedPattern))
             )
               AND Id NOT IN :recentlyNotifiedAccountIds
               AND Timesolv_TrustAccount_Replenish_Below__c > 0
               AND Timesolv_TrustAccount_Replenish_To__c > 0
               AND (
                    Timesolv_TrustAccount_Balance__c = 0
                    OR Timesolv_TrustAccount_Balance__c = null
               )
        ]);
    }

    /**
     * @description Returns active Users keyed by Id.
     * @param userIds Responsible Attorney Ids to check.
     * @return Map of active Users.
     */
    public Map<Id, User> getActiveUsersById(Set<Id> userIds) {
        if (userIds == null || userIds.isEmpty()) {
            return new Map<Id, User>();
        }

        return new Map<Id, User>([
            SELECT Id, IsActive
              FROM User
             WHERE Id IN :userIds
               AND IsActive = true
        ]);
    }

    /**
     * @description Returns suppression Tasks by Account Id, oldest first.
     *              Only the first two matter for reminder logic.
     * @param accountIds Scope Account Ids.
     * @param taskSubject Suppression Task subject.
     * @return Map<AccountId, List<Task>> ordered by CreatedDate ascending.
     */
    public Map<Id, List<Task>> getSuppressionTasksByAccountId(Set<Id> accountIds, String taskSubject) {
        Map<Id, List<Task>> results = new Map<Id, List<Task>>();

        if (accountIds == null || accountIds.isEmpty()) {
            return results;
        }

        for (Task t : [
            SELECT Id,
                   WhatId,
                   WhoId,
                   CreatedDate
              FROM Task
             WHERE WhatId IN :accountIds
               AND Subject = :taskSubject
             ORDER BY WhatId ASC, CreatedDate ASC
        ]) {
            if (!results.containsKey(t.WhatId)) {
                results.put(t.WhatId, new List<Task>());
            }

            if (results.get(t.WhatId).size() < 2) {
                results.get(t.WhatId).add(t);
            }
        }

        return results;
    }

    /**
     * @description Resolves the Org-Wide Email Address Id by Address.
     * @param emailAddress Org-Wide Email Address value.
     * @return OrgWideEmailAddress Id or null.
     */
    public Id getOrgWideEmailAddressId(String emailAddress) {
        List<OrgWideEmailAddress> rows = [
            SELECT Id
              FROM OrgWideEmailAddress
             WHERE Address = :emailAddress
             LIMIT 1
        ];

        return rows.isEmpty() ? null : rows[0].Id;
    }

    /**
     * @description Resolves email templates by DeveloperName.
     * @param developerNames Template developer names.
     * @return Map<DeveloperName, TemplateId>.
     */
    public Map<String, Id> getEmailTemplateIds(Set<String> developerNames) {
        Map<String, Id> results = new Map<String, Id>();

        if (developerNames == null || developerNames.isEmpty()) {
            return results;
        }

        for (EmailTemplate templateRow : [
            SELECT Id, DeveloperName
              FROM EmailTemplate
             WHERE DeveloperName IN :developerNames
        ]) {
            results.put(templateRow.DeveloperName, templateRow.Id);
        }

        return results;
    }

    /**
     * @description Inserts suppression Tasks with partial success.
     * @param tasksToInsert Tasks to insert.
     * @return SaveResults in matching order.
     */
    public Database.SaveResult[] insertSuppressionTasks(List<Task> tasksToInsert) {
        if (tasksToInsert == null || tasksToInsert.isEmpty()) {
            return new List<Database.SaveResult>();
        }

        return Database.insert(tasksToInsert, false);
    }
}