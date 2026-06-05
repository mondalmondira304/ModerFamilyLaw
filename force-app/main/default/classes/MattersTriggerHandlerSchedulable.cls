public with sharing class MattersTriggerHandlerSchedulable implements Schedulable {
  public void execute(SchedulableContext SC) {
     MattersTriggerHandler.createMatterShares();
  }
}