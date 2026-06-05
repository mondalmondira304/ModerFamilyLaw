public without sharing class AdobeSignAttySigningUrl {
    private static final String CLASS_NAME = 'AdobeSignAttySigningUrl';

    @TestVisible
    private static String testAttorneyEmailOverride;
    
    public class InputWrapper {
        @InvocableVariable(required=true)
        public Id accountId;
    }
    public class OutputWrapper {
        @InvocableVariable public Id accountId;
        @InvocableVariable public String attorneySigningUrl;
    }
    @InvocableMethod(label='Create Attorney Signing URL (Async Queueable)')
    public static List<OutputWrapper> createAttySigningUrl(List<InputWrapper> inputs) {
        List<OutputWrapper> results = new List<OutputWrapper>();
        if (inputs == null || inputs.isEmpty()) {
            return results;
        }
        Set<Id> accountIds = new Set<Id>();
        for (InputWrapper inp : inputs) {
            if (inp != null && inp.accountId != null) {
                accountIds.add(inp.accountId);
            }
        }
        if (accountIds.isEmpty()) {
            return results;
        }
        Map<Id, Account> accMap = new Map<Id, Account>([
            SELECT Id,Name,
                   FA_Portal_AgreementId__c,
                   FA_Portal_Atty_Signing_URL__c
            FROM Account
            WHERE Id IN :accountIds
        ]);
        for (InputWrapper inp : inputs) {
            OutputWrapper out = new OutputWrapper();
            out.accountId = inp == null ? null : inp.accountId;
            if (inp == null || inp.accountId == null) {
                results.add(out);
                continue;
            }
            Account acc = accMap.get(inp.accountId);

            if (acc == null) {
                results.add(out);
                continue;
            }
            String agreementId = acc.FA_Portal_AgreementId__c;
            if (String.isBlank(agreementId)) {
                results.add(out);
                continue;
            }
            
            System.enqueueJob(new AdobeSignAttyUrlQueueable(acc.Id, agreementId));
            out.attorneySigningUrl = acc.FA_Portal_Atty_Signing_URL__c;
            results.add(out);
        }
        return results;
    }

    /**
     * Send attorney email notification when signing URL is ready
     * Call this method from the Queueable after URL is successfully created
     */
    public static void sendAttorneySigningNotification(Id accountId, String signingUrl) {
        if (String.isBlank(signingUrl)) {
            return;
        }

        List<Account> accounts = [
            SELECT Id, 
                   Name,
                   FA_Portal_AgreementId__c,
                   Responsible_Attorney_First_Name_A__c,
                   Responsible_Attorney_Email_A__c
            FROM Account
            WHERE Id = :accountId
            LIMIT 1
        ];

        if (accounts.isEmpty()) {
            return;
        }

        Account acc = accounts[0];

        String toEmail = String.isNotBlank(testAttorneyEmailOverride)
            ? testAttorneyEmailOverride
            : acc.Responsible_Attorney_Email_A__c;

        if (String.isBlank(toEmail)) {
            return;
        }

        Messaging.SingleEmailMessage email = new Messaging.SingleEmailMessage();
        email.setToAddresses(new String[] { toEmail });
        email.setSubject('Fee Agreement Modern Family Law - Ready to Sign');
        email.setHtmlBody(getEmailTemplate(acc.Responsible_Attorney_First_Name_A__c, signingUrl, acc.Name));
        
        List<OrgWideEmailAddress> owea = [
            SELECT Id 
            FROM OrgWideEmailAddress 
            WHERE Address = 'reception@modernfamilylaw.com'
            LIMIT 1
        ];
        if (!owea.isEmpty()) {
            email.setOrgWideEmailAddressId(owea[0].Id);
        }
        
        try {
            Messaging.sendEmail(new Messaging.SingleEmailMessage[] { email });
        } catch (Exception e) {
            AdobeFaErrorLogUtil.logError(
                CLASS_NAME,
                'sendAttorneySigningNotification',
                e,
                accountId
            );
        }
    }

    /**
     * Generate HTML email template
     */
    private static String getEmailTemplate(String firstName, String signingUrl, String accountName) {
        String greeting = String.isNotBlank(firstName) ? 'Hi ' + firstName : 'Hello';
        
        return '<!DOCTYPE html>' +
            '<html>' +
            '<head>' +
            '<meta charset="UTF-8">' +
            '<meta name="viewport" content="width=device-width, initial-scale=1.0">' +
            '</head>' +
            '<body style="margin: 0; padding: 0; font-family: -apple-system, BlinkMacSystemFont, \'Segoe UI\', Roboto, \'Helvetica Neue\', Arial, sans-serif; background-color: #f5f5f5;">' +
            '<table width="100%" cellpadding="0" cellspacing="0" style="background-color: #f5f5f5; padding: 40px 20px;">' +
            '<tr>' +
            '<td align="center">' +
            '<table width="600" cellpadding="0" cellspacing="0" style="background-color: #ffffff; border-radius: 8px; box-shadow: 0 2px 8px rgba(0,0,0,0.1);">' +
            '<tr>' +
            '<td style="padding: 40px 40px 20px 40px; text-align: center; color: #3c3c3c; font-size: 18px; line-height: 1.4;">' +
            '<p style="margin: 0 0 8px 0;">' + accountName + ' requests your signature on</p>' +
            '<p style="margin: 0; color: #0176D3; font-size: 22px; font-weight: 600;">Fee Agreement Modern Family Law</p>' +
            '</td>' +
            '</tr>' +
            '<tr>' +
            '<td style="padding: 20px 40px 30px 40px; text-align: center;">' +
            '<a href="' + signingUrl + '" style="display: inline-block; background-color: #0176D3; color: #ffffff; text-decoration: none; padding: 14px 32px; border-radius: 4px; font-size: 16px; font-weight: 600;">Review and sign</a>' +
            '</td>' +
            '</tr>' +
            '<tr>' +
            '<td style="padding: 0 40px; border-top: 1px solid #e0e0e0;">' +
            '</td>' +
            '</tr>' +
            '<tr>' +
            '<td style="padding: 30px 40px 20px 40px; color: #333333; font-size: 15px; line-height: 1.6;">' +
            '<p style="margin: 0 0 16px 0;">' + greeting + ',</p>' +
            '<p style="margin: 0 0 16px 0;">Your signing URL for <strong>Fee Agreement Modern Family Law</strong> is ready. Please review and sign the agreement at your earliest convenience.</p>' +
            '<p style="margin: 0 0 16px 0;">After you sign, all parties will receive a final PDF copy.</p>' +
            '</td>' +
            '</tr>' +
            '<tr>' +
            '<td style="padding: 20px 40px 40px 40px;">' +
            '</td>' +
            '</tr>' +
            '</table>' +
            '</td>' +
            '</tr>' +
            '</table>' +
            '</body>' +
            '</html>';
    }
}