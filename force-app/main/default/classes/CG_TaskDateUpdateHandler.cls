public class CG_TaskDateUpdateHandler {
    
    public static void verifyDueDate(Set<Id> idSet) {

        List<Task> taskList = new List<Task>();
        //Query Tasks and Matter date fields
        Set<String> linkedFieldSet = CG_DateChangeUtils.getLinkedFieldSet();

        String temp = '';
        for(String s : linkedFieldSet){
            temp += s + ',';
        }

        String query = 'SELECT id, ActivityDate, Date_Push__c, Linked_Date__c, TYPEOF What WHEN Matters__c THEN '
                        + temp + 'Id END FROM Task WHERE id in :idSet';
        taskList = Database.query(query);

        //Verify due date is valid
        for(Task t : taskList) {
            if(t.What instanceOf Matters__c) {
                Matters__c m = t.What;
                if((Date)m.get(t.Linked_Date__c) != null){       
                    t.ActivityDate = CG_DateChangeUtils.getValidDate((Date)m.get(t.Linked_Date__c), t.Date_Push__c.IntValue());
                }
            }
        }
        update taskList;
    }

    public static void handleMatterUpdateNew(Set<Id> matterIdSet) {

        List<Task> taskList = new List<Task>();
        List<Task> toUpdateTaskList = new List<Task>();

        Set<String> linkedFieldSet = new Set<String>();

        Map<Id, List<String>> matterFieldMap = new Map<Id, List<String>>();
        Set<Id> tempSet = new Set<Id>();
        

        linkedFieldSet = CG_DateChangeUtils.getLinkedFieldSet();

        String temp = '';
        for(String s : linkedFieldSet){
            if (String.isNotBlank(s)) {
                temp += s + ',';
            }
        }
        
        String query = 'SELECT id, ActivityDate, Date_Push__c, Linked_Date__c, TYPEOF What WHEN Matters__c THEN '
                        + temp + 'Id END FROM Task WHERE Whatid in :matterIdSet AND Linked_Date__c != null AND isClosed = false';
        taskList = Database.query(query);

        for(Task t : taskList) {
            // if(t.Linked_Date__c != null){
            Matters__c m = t.What;
            if((Date)m.get(t.Linked_Date__c) != null){    
                Date tempDate = t.ActivityDate;
                
                t.ActivityDate = CG_DateChangeUtils.getValidDate((Date)m.get(t.Linked_Date__c), t.Date_Push__c.IntValue());

                if(tempDate != t.ActivityDate) {
                    toUpdateTaskList.add(t);
                }
            }
        }

        if(toUpdateTaskList.size() > 0){
            update toUpdateTaskList;
        }
    }

     // public static void handleMatterUpdate(List<Matters__c> newList, Map<Id, Matters__c> oldMap) {
    //     Set<String> linkedFieldSet = new Set<String>();
    //     Map<Id, List<String>> matterFieldMap = new Map<Id, List<String>>();
    //     List<Task> taskList = new List<Task>();
    //     List<Task> updateTaskList = new List<Task>();
        
    //     linkedFieldSet = CG_DateChangeUtils.getLinkedFieldSet();
    //     //System.debug(linkedFieldSet.toString());
        
    //     //loop though newMap and determine if a linkedfield was updated. Add to map<Id, linkedfield>.
    //     for(Matters__c m : newList) {
    //         for(String s : linkedFieldSet) {
    //             try{
    //                 if(m.get(s) != null) {
    //                     if(m.get(s) != oldMap.get(m.Id).get(s)){
    //                         if(matterFieldMap.containsKey(m.id)){
    //                             matterFieldMap.get(m.Id).add(s);
    //                         } else {
    //                             List<String> temp = new List<String>();
    //                             temp.add(s);
    //                             matterFieldMap.put(m.Id, temp);
    //                         }
    //                     }
    //                 }
    //             }catch(Exception e){
    //                 System.debug(e.getMessage());
    //             }
    //         }
    //     }

    //     //Get list of tasks related to matters that were updated
    //     String temp = '';
    //     for(String s : linkedFieldSet){
    //         temp += s + ',';
    //     }

    //     Set<Id> tempSet = new Set<Id>();
    //     tempSet.addAll(matterFieldMap.keySet());

    //     String query = 'SELECT id, ActivityDate, Date_Push__c, Linked_Date__c, TYPEOF What WHEN Matters__c THEN '
    //                     + temp + 'Id END FROM Task WHERE Whatid in :tempSet';
    //     taskList = Database.query(query);

    //     //update dates for tasks that need to be updated
    //     for(Task t : taskList) {
    //         if(matterFieldMap.get(t.WhatId).contains(t.Linked_Date__c)){
    //             Matters__c m = t.What;
    //             t.ActivityDate = CG_DateChangeUtils.getValidDate((Date)m.get(t.Linked_Date__c), t.Date_Push__c.IntValue());
    //             updateTaskList.add(t);
    //         }
    //     }

    //     if(updateTaskList.size() > 0){
    //         update updateTaskList;
    //     }
    // }

}