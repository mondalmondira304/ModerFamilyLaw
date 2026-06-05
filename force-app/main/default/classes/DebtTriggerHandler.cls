public class DebtTriggerHandler {

    public static void checkMatterId(List<Debt__c> debt) {
        List<Debt__c> queue = new List<Debt__c>();
        Set<Id> matterIds = new Set<Id>();
        // Checks if incoming DEbt ("Debt") record has a Matter Id 
        // If Matter Id exists, code will use it to find the existing Matter and stamp the related Client Account 
        for (Debt__c d : debt) {
            if (d.Related_Matter__c != null && d.Related_To__c == null) {
                queue.add(d);
                matterIds.add(d.Related_Matter__c);
            }
        }

        if (!matterIds.isEmpty()) {
            getAndStampClient(queue, matterIds);
        }
    }

    private static void getAndStampClient(List<Debt__c> debt, Set<Id> matterIds) {
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
            for (Debt__c d : debt) {
                if (clientIdByMatterId.containsKey(d.Related_Matter__c)) {
                    d.Related_To__c = clientIdByMatterId.get(d.Related_Matter__c);
                }
            }
        }
    }
    
}