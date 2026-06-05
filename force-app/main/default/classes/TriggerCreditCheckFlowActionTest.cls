@isTest
public class TriggerCreditCheckFlowActionTest {
    @isTest private static void triggerCreditCheckTest() {
        List<Account> accts=new List<Account>();
        User thisUser = [SELECT Id FROM User WHERE Id = :UserInfo.getUserId()];        
        System.runAs (thisUser) {  //use System.runAs() to avoid mixed DML errors   
            accts=TestDataFactory.getPersonAccounts(1);             
        }
        TriggerCreditCheckFlowAction.TriggerCreditCheckResult result=  TriggerCreditCheckFlowAction.triggerCreditCheck(accts[0].Id);
        system.assertEquals('Success',result.status);
        result=  TriggerCreditCheckFlowAction.triggerCreditCheck('');
        system.assertEquals('Error',result.status);
    }
}