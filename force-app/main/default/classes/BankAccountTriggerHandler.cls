public class BankAccountTriggerHandler {

    public static void checkMatterId(List<Bank_Account__c> accts) {
        List<Bank_Account__c> queue = new List<Bank_Account__c>();
        Set<Id> matterIds = new Set<Id>();
        // Checks if incoming Bank Account ("Bank Account") record has a Matter Id 
        // If Matter Id exists, code will use it to find the existing Matter and stamp the related Client Account 
        for (Bank_Account__c a : accts) {
            if (a.Related_Matter__c != null && a.Related_To__c == null) {
                queue.add(a);
                matterIds.add(a.Related_Matter__c);
            }
        }

        if (!matterIds.isEmpty()) {
            getAndStampClient(queue, matterIds);
        }
    }

    private static void getAndStampClient(List<Bank_Account__c> accts, Set<Id> matterIds) {
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
            for (Bank_Account__c a : accts) {
                if (clientIdByMatterId.containsKey(a.Related_Matter__c)) {
                    a.Related_To__c = clientIdByMatterId.get(a.Related_Matter__c);
                }
            }
        }
    }
    
}