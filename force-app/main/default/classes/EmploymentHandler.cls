public class EmploymentHandler {

    public static void checkMatterId(List<Employment__c> employment) {
        List<Employment__c> queue = new List<Employment__c>();
        Set<Id> matterIds = new Set<Id>();
        // Checks if incoming ("Employment") record has a Matter Id 
        // If Matter Id exists, code will use it to find the existing Matter and stamp the related Client Account 
        for (Employment__c e : employment) {
            if (e.Related_Matter__c != null && e.Related_To__c == null) {
                queue.add(e);
                matterIds.add(e.Related_Matter__c);
            }
        }

        if (!matterIds.isEmpty()) {
            getAndStampClient(queue, matterIds);
        }
    }

    private static void getAndStampClient(List<Employment__c> employment, Set<Id> matterIds) {
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
            for (Employment__c e : employment) {
                if (clientIdByMatterId.containsKey(e.Related_Matter__c)) {
                    e.Related_To__c = clientIdByMatterId.get(e.Related_Matter__c);
                }
            }
        }
    }
    
}