public class LifeInsuranceTriggerHandler {

    public static void checkMatterId(List<Life_Insurance__c> accts) {
        List<Life_Insurance__c> queue = new List<Life_Insurance__c>();
        Set<Id> matterIds = new Set<Id>();
        // Checks if incoming Housing ("Life Insurance") record has a Matter Id 
        // If Matter Id exists, code will use it to find the existing Matter and stamp the related Client Account 
        for (Life_Insurance__c a : accts) {
            if (a.Related_Matter__c != null) {
                queue.add(a);
                matterIds.add(a.Related_Matter__c);
            }
        }

        if (!matterIds.isEmpty()) {
            getAndStampClient(queue, matterIds);
        }
    }

    private static void getAndStampClient(List<Life_Insurance__c> accts, Set<Id> matterIds) {
        Map<Id, Id> clientIdByMatterId = new Map<Id, Id>();
        for (Matters__c m : [
            SELECT Id, Client_Name__c
            FROM Matters__c 
            WHERE Id IN :matterIds
            AND Client_Name__c != null
        ]) {
            clientIdByMatterId.put(m.Id, m.Client_Name__c);
        }

        if (!clientIdByMatterId.keySet().isEmpty()) {
            for (Life_Insurance__c a : accts) {
                if (clientIdByMatterId.containsKey(a.Related_Matter__c)) {
                    a.Client__c = clientIdByMatterId.get(a.Related_Matter__c);
                }
            }
        }
    }
    
}