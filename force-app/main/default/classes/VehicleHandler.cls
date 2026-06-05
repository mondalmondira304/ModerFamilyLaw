public class VehicleHandler {

    public static void checkMatterId(List<Vehicle__c> vehicles) {
        List<Vehicle__c> queue = new List<Vehicle__c>();
        Set<Id> matterIds = new Set<Id>();
        // Checks if incoming ("Vehicle") record has a Matter Id 
        // If Matter Id exists, code will use it to find the existing Matter and stamp the related Client Account 
        for (Vehicle__c v : vehicles) {
            if (v.Related_Matter__c != null && v.Related_To__c == null) {
                queue.add(v);
                matterIds.add(v.Related_Matter__c);
            }
        }

        if (!matterIds.isEmpty()) {
            getAndStampClient(queue, matterIds);
        }
    }

    private static void getAndStampClient(List<Vehicle__c> vehicles, Set<Id> matterIds) {
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
            for (Vehicle__c v : vehicles) {
                if (clientIdByMatterId.containsKey(v.Related_Matter__c)) {
                    v.Related_To__c = clientIdByMatterId.get(v.Related_Matter__c);
                }
            }
        }
    }
    
}