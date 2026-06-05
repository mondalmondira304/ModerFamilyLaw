public class PersonalPropTriggerHandler {

    public static void checkMatterId(List<Furniture_Personal_Property__c> props) {
        List<Furniture_Personal_Property__c> queue = new List<Furniture_Personal_Property__c>();
        Set<Id> matterIds = new Set<Id>();
        // Checks if incoming ("Furniture/Personal Property") record has a Matter Id 
        // If Matter Id exists, code will use it to find the existing Matter and stamp the related Client Account 
        for (Furniture_Personal_Property__c p : props) {
            if (p.Related_Matter__c != null && p.Related_Account__c == null) {
                queue.add(p);
                matterIds.add(p.Related_Matter__c);
            }
        }

        if (!matterIds.isEmpty()) {
            getAndStampClient(queue, matterIds);
        }
    }

    private static void getAndStampClient(List<Furniture_Personal_Property__c> props, Set<Id> matterIds) {
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
            for (Furniture_Personal_Property__c p : props) {
                if (clientIdByMatterId.containsKey(p.Related_Matter__c)) {
                    p.Related_Account__c = clientIdByMatterId.get(p.Related_Matter__c);
                }
            }
        }
    }
    
}