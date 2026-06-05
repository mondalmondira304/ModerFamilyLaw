trigger UserTrigger on User (before insert, after insert, before update, after update) {
    UserTriggerHandler.runUserTriggerLogic();
}