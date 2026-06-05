public class TaxesHandler {

    public static void checkMatterId(List<Taxes__c> taxes) {
        List<Taxes__c> queue = new List<Taxes__c>();
        Set<Id> matterIds = new Set<Id>();
        // Checks if incoming ("Taxes") record has a Matter Id 
        // If Matter Id exists, code will use it to find the existing Matter and stamp the related Client Account 
        for (Taxes__c t : taxes) {
            if (t.Matter_ID__c != null && t.Related_To__c == null) {
                queue.add(t);
                matterIds.add(t.Matter_ID__c);
            }
        }

        if (!matterIds.isEmpty()) {
            getAndStampClient(queue, matterIds);
        }
    }

    private static void getAndStampClient(List<Taxes__c> taxes, Set<Id> matterIds) {
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
            for (Taxes__c t : taxes) {
                if (clientIdByMatterId.containsKey(t.Matter_ID__c)) {
                    t.Related_To__c = clientIdByMatterId.get(t.Matter_ID__c);
                }
            }
        }
    }
    
}