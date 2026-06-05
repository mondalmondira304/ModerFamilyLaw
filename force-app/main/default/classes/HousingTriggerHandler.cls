public class HousingTriggerHandler {

    public static void checkMatterId(List<Housing__c> housing) {
        List<Housing__c> queue = new List<Housing__c>();
        Set<Id> matterIds = new Set<Id>();
        // Checks if incoming Housing ("Housing") record has a Matter Id 
        // If Matter Id exists, code will use it to find the existing Matter and stamp the related Client Account 
        for (Housing__c h : housing) {
            if (h.Related_Matter__c != null) {
                queue.add(h);
                matterIds.add(h.Related_Matter__c);
            }
        }

        if (!matterIds.isEmpty()) {
            getAndStampClient(queue, matterIds);
        }
    }

    private static void getAndStampClient(List<Housing__c> housing, Set<Id> matterIds) {
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
            for (Housing__c h : housing) {
                if (clientIdByMatterId.containsKey(h.Related_Matter__c)) {
                    h.Client__c = clientIdByMatterId.get(h.Related_Matter__c);
                }
            }
        }
    }
    
}