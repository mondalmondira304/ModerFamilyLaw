@IsTest(SeeAllData = true)
public with sharing class LightningForgotPasswordControllerTest {

 /* Verifies that ForgotPasswordController handles invalid usernames appropriately */
 @IsTest
 static void testLightningForgotPasswordControllerInvalidUserName() {
  System.assertEquals(LightningForgotPasswordController.forgotPassword('fakeUser', 'http://a.com'), Label.Site.invalid_email);
  System.assertEquals(LightningForgotPasswordController.forgotPassword(null, 'http://a.com'), Label.Site.invalid_email);
  System.assertEquals(LightningForgotPasswordController.forgotPassword('a', '/home/home.jsp'), Label.Site.invalid_email);
 }

 /* Verifies that null checkEmailRef url throws proper exception. */
 @IsTest
 static void testLightningForgotPasswordControllerWithNullCheckEmailRef() {
  System.assertEquals(LightningForgotPasswordController.forgotPassword('a', null), 'Argument 1 cannot be null');
  System.assertEquals(LightningForgotPasswordController.forgotPassword('a@salesforce.com', null), 'Argument 1 cannot be null');
 }

 /* Verifies that LightningForgotPasswordController object is instantiated correctly. */
 @IsTest
 static void LightningForgotPasswordControllerInstantiation() {
  LightningForgotPasswordController controller = new LightningForgotPasswordController();
  System.assertNotEquals(controller, null);
 }
 	@isTest
    static void testSetExperienceId_withMockedId() {
        Id mockedExpId = '0DB000000000001';

        Test.startTest();
        String result = LightningForgotPasswordController.setExperienceId(mockedExpId);
        Test.stopTest();

        System.assertEquals('This method can be invoked only from within a community.', result, 'Expected null when setting a mocked Experience Id');
    }

    @isTest
    static void testSetExperienceId_withNull() {
        Test.startTest();
        String result = LightningForgotPasswordController.setExperienceId(null);
        Test.stopTest();

        System.assertEquals(null, result, 'Expected null when Experience Id is not provided');
    }

}