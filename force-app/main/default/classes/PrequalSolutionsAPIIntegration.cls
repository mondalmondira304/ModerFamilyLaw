@isTest
public with sharing class PrequalSolutionsAPIIntegration {
    Public String s;
    public PrequalSolutionsAPIIntegration(String input) {
        s=input;
    }
@isTest
   static void dummyTest(){
        PrequalSolutionsAPIIntegration t =new PrequalSolutionsAPIIntegration('x');
        system.assertEquals('x', t.s);
   }
}