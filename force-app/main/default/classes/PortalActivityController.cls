/**
 * PortalActivityController
 *
 * Returns Activity (Task) records as client-facing "Recent Updates" for the
 * portal dashboard and the View All Updates page.
 *
 * Filter rule (provisional — Skylar to confirm):
 *   - Task.WhatId = the current user's Account, OR linked to a Matter owned by them
 *   - Status = 'Completed'  (we only show things that actually happened)
 *   - Type != 'CI Form'     (CI Form tasks are internal progress tracking)
 *
 * Each row is shaped server-side into the view-model the LWC binds against,
 * so the JS doesn't have to do per-Type icon mapping.
 */
public with sharing class PortalActivityController {

    // Icon/color mapping by Task.Type. Anything not in this map gets the
    // default (notification + blue). Order is irrelevant.
    private static final Map<String, Map<String, String>> ICON_MAP = new Map<String, Map<String, String>>{
        'Email'          => new Map<String, String>{ 'icon' => 'utility:email',        'iconClass' => 'update-icon-wrap update-icon-teal'  },
        'Call'           => new Map<String, String>{ 'icon' => 'utility:call',         'iconClass' => 'update-icon-wrap update-icon-blue'  },
        'Document'       => new Map<String, String>{ 'icon' => 'utility:upload',       'iconClass' => 'update-icon-wrap update-icon-amber' },
        'Payment'        => new Map<String, String>{ 'icon' => 'utility:check',        'iconClass' => 'update-icon-wrap update-icon-green' },
        'Finance Inquiry'=> new Map<String, String>{ 'icon' => 'utility:currency',     'iconClass' => 'update-icon-wrap update-icon-green' }
    };
    private static final Map<String, String> DEFAULT_ICON = new Map<String, String>{
        'icon' => 'utility:notification', 'iconClass' => 'update-icon-wrap update-icon-blue'
    };

    @AuraEnabled(cacheable=true)
    public static List<ActivityItem> getRecentActivities(Integer limitN) {
        try {
            Id accountId = MatterController.getCurrentUserAccountId();
            if (accountId == null) {
                return new List<ActivityItem>();
            }
            Integer rowLimit = (limitN == null || limitN <= 0) ? 4 : Math.min(limitN, 200);

            // Pull matter Ids so we can include tasks logged against the Matter
            // (not just the Account) — e.g. document uploads to a Matter.
            Set<Id> whatIds = new Set<Id>{ accountId };
            for (Matters__c m : [
                SELECT Id FROM Matters__c
                WHERE Client_Name__r.Id = :accountId
                  AND Status__c NOT IN ('Closed', 'Refund Due')
            ]) {
                whatIds.add(m.Id);
            }

            List<Task> tasks = [
                SELECT Id, Subject, Type, ActivityDate, CreatedDate, WhatId
                FROM Task
                WHERE WhatId IN :whatIds
                  AND Status = 'Completed'
                  AND Type != 'CI Form'
                ORDER BY CreatedDate DESC
                LIMIT :rowLimit
            ];

            List<ActivityItem> out = new List<ActivityItem>();
            for (Task t : tasks) {
                out.add(shape(t));
            }
            return out;
        } catch (Exception e) {
            Utility.createFutureErrorRecord(
                e.getMessage(), e.getStackTraceString(), e.getLineNumber(),
                e.getTypeName(), 'PortalActivityController.getRecentActivities'
            );
            throw new AuraHandledException('Could not load recent updates: ' + e.getMessage());
        }
    }

    private static ActivityItem shape(Task t) {
        Map<String, String> iconCfg = ICON_MAP.containsKey(t.Type) ? ICON_MAP.get(t.Type) : DEFAULT_ICON;
        ActivityItem item = new ActivityItem();
        item.id = t.Id;
        item.text = String.isBlank(t.Subject) ? (t.Type == null ? 'Activity' : t.Type) : t.Subject;
        item.icon = iconCfg.get('icon');
        item.iconClass = iconCfg.get('iconClass');
        Date d = (t.ActivityDate != null) ? t.ActivityDate : t.CreatedDate.date();
        item.dateLabel = formatDate(d);
        return item;
    }

    private static String formatDate(Date d) {
        if (d == null) return '';
        // "May 5, 2026" — matches design mockup
        return DateTime.newInstance(d.year(), d.month(), d.day()).format('MMMM d, yyyy');
    }

    /**
     * View-model returned to LWC. Pre-shaped so the client just binds.
     */
    public class ActivityItem {
        @AuraEnabled public String id;
        @AuraEnabled public String text;
        @AuraEnabled public String icon;
        @AuraEnabled public String iconClass;
        @AuraEnabled public String dateLabel;  // formatted display string (`date` is a reserved Apex identifier)
    }
}