trigger HubSpotAccountTrigger on Account (after insert) {
    if (Trigger.isAfter && Trigger.isInsert) {
        HubSpotAccountTriggerHandler.handleAfterInsert(Trigger.new);
    }
}