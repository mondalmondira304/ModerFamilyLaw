public class CreditCardHandler {

    public static void checkMatterId(List<Credit_Card__c> cards) {
        List<Credit_Card__c> queue = new List<Credit_Card__c>();
        Set<Id> matterIds = new Set<Id>();
        // Checks if incoming ("Credit Card") record has a Matter Id 
        // If Matter Id exists, code will use it to find the existing Matter and stamp the related Client Account 
        for (Credit_Card__c c : cards) {
            if (c.Matter_ID__c != null && c.Account_Owner__c == null) {
                queue.add(c);
                matterIds.add(c.Matter_ID__c);
            }
        }

        if (!matterIds.isEmpty()) {
            getAndStampClient(queue, matterIds);
        }
    }  

    private static void getAndStampClient(List<Credit_Card__c> cards, Set<Id> matterIds) {
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
            for (Credit_Card__c c : cards) {
                if (clientIdByMatterId.containsKey(c.Matter_ID__c)) {
                    c.Account_Owner__c = clientIdByMatterId.get(c.Matter_ID__c);
                }
            }
        }
    }
    
}