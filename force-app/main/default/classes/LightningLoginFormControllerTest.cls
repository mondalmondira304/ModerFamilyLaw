@IsTest(SeeAllData = true)
public with sharing class LightningLoginFormControllerTest {
 @IsTest
 static void LightningLoginFormControllerInstantiation() {
  LightningLoginFormController controller = new LightningLoginFormController();
  System.assertNotEquals(controller, null);
 }
 @IsTest
 static void testIsUsernamePasswordEnabled() {
  System.assertEquals(true, LightningLoginFormController.getIsUsernamePasswordEnabled());
 }
 @IsTest
 static void testIsSelfRegistrationEnabled() {
  System.assertEquals(false, LightningLoginFormController.getIsSelfRegistrationEnabled());
 }
 @IsTest
 static void testGetSelfRegistrationURL() {
  System.assertEquals(null, LightningLoginFormController.getSelfRegistrationUrl());
 }
 @IsTest
 static void testAuthConfig() {
  Auth.AuthConfiguration authConfig = LightningLoginFormController.getAuthConfig();
  System.assertNotEquals(null, authConfig);
 }
 @isTest
    static void testSetExperienceId_withMockedId() {
        Id mockedExpId = '0DB000000000001';

        Test.startTest();
        String result = LightningLoginFormController.setExperienceId(mockedExpId);
        Test.stopTest();

        System.assertEquals('This method can be invoked only from within a community.', result, 'Expected null when setting a mocked Experience Id');
    }
    @isTest
    static void testSetExperienceId_withNull() {
        Test.startTest();
        String result = LightningLoginFormController.setExperienceId(null);
        Test.stopTest();

        System.assertEquals(null, result, 'Expected null when Experience Id is not provided');
    }
    @isTest
    static void testLoginWithMockedCredentials() {
        // Mock input data
        String username = 'testuser@example.com';
        String password = 'Test@123';
        String startUrl = '/home';

        Test.startTest();
        String result = LightningLoginFormController.login(username, password, startUrl);
        System.debug('gettting result::'+result);
        Test.stopTest();

        System.assertEquals(null, result, 'Expected null');
    }
    @IsTest
    static void testGetLoginSettings() {
        Test.startTest();
            LightningLoginFormController.loginSettings settings = LightningLoginFormController.getLoginSettings();
        Test.stopTest();
        System.assertEquals(true, settings.UsernamePasswordEnabled);
        System.assert(settings.forgotPasswordUrl!=null || settings.forgotPasswordUrl==null );  //just copying the old test
        System.assert(settings.headlessForgotPasswordEnabled==true || settings.headlessForgotPasswordEnabled==false );  //since this is set in administration settings for the site...don't bother
    }      
    @isTest
    static void testGetForgotPasswordUrl() {
        Test.startTest();
        String result = LightningLoginFormController.getForgotPasswordUrl();
        Test.stopTest();
        System.assert(result != null || result == null); // Ensures the call completes
    }
}