global class LightningLoginFormController {

    public LightningLoginFormController() {
        
    }    
    public class loginSettings{
        @AuraEnabled public Boolean usernamePasswordEnabled;
        @AuraEnabled public String forgotPasswordUrl;
        @AuraEnabled public Boolean headlessForgotPasswordEnabled;
    }
    @AuraEnabled
    public static String login(String username, String password, String startUrl) {
        try{
            ApexPages.PageReference lgn = Site.login(username, password, startUrl);
            aura.redirect(lgn);
            return String.valueOf(lgn);
        }
        catch (Exception ex) {
            return ex.getMessage();            
        }
    }
    @AuraEnabled
    public static loginSettings getLoginSettings(){
        try {
            loginSettings settings = new loginSettings();
            Auth.AuthConfiguration authConfig = getAuthConfig();
            settings.usernamePasswordEnabled = authConfig.getUsernamePasswordEnabled();   
            settings.forgotPasswordUrl = authConfig.getForgotPasswordUrl();             
            settings.headlessForgotPasswordEnabled = authConfig.getHeadlessForgotPasswordEnabled();                    
            return settings;
        }catch (Exception e) {
            Utility.createErrorRecord(e.getMessage(), e.getStackTraceString(), e.getLineNumber(), e.getTypeName(), 'LightningLoginFormController.getLoginSettings');
            throw new AuraHandledException('Error with getLoginSettings:  ' + e.getMessage());            
        }
    }
    @AuraEnabled(cacheable=true)
    public static Boolean getIsUsernamePasswordEnabled() { // bundle
        Auth.AuthConfiguration authConfig = getAuthConfig();
        return authConfig.getUsernamePasswordEnabled();
    }

    @AuraEnabled
    public static Boolean getIsSelfRegistrationEnabled() {
        Auth.AuthConfiguration authConfig = getAuthConfig();
        return authConfig.getSelfRegistrationEnabled();
    }

    @AuraEnabled
    public static String getSelfRegistrationUrl() {
        Auth.AuthConfiguration authConfig = getAuthConfig();
        if (authConfig.getSelfRegistrationEnabled()) {
            return authConfig.getSelfRegistrationUrl();
        }
        return null;
    }

    @AuraEnabled(cacheable=true)
    public static String getForgotPasswordUrl() { //bundle
        Auth.AuthConfiguration authConfig = getAuthConfig();
        return authConfig.getForgotPasswordUrl();
    }

    @AuraEnabled(cacheable=true)
    public static Boolean getIsHeadlessForgotPasswordEnabled() { //bundle
        Auth.AuthConfiguration authConfig = getAuthConfig();
        return authConfig.getHeadlessForgotPasswordEnabled();
    }
    
    @TestVisible
    private static Auth.AuthConfiguration getAuthConfig(){
        Id networkId = Network.getNetworkId();
        Auth.AuthConfiguration authConfig = new Auth.AuthConfiguration(networkId,'');
        return authConfig;
    }

    @AuraEnabled
    global static String setExperienceId(String expId) {
        // Return null if there is no error, else it will return the error message 
        try {
            if (expId != null) {
                Site.setExperienceId(expId);
            }
            return null; 
        } catch (Exception ex) {
            return ex.getMessage();            
        }
    }   
}