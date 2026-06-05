trigger AdditionalAssetsTrigger on Additional_Asset__c (before insert, before update) {
    if (Trigger.isInsert || Trigger.isUpdate) {
        if (Trigger.isBefore) {
            AdditionalAssetsHandler.checkMatterId(Trigger.new);
        }
    }
}