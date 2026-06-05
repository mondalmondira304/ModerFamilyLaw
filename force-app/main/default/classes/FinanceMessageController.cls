/**
 * FinanceMessageController
 *
 * Receives the Contact Finance form submission from the portal, emails the
 * finance team, and logs a Task on the requesting client's Account so the
 * inquiry shows up in their "Recent Updates" feed.
 *
 * TODO: replace FINANCE_EMAIL with a Custom Metadata lookup once the
 *       Portal_Config__mdt (or similar) is created. Skylar/Don to confirm.
 */
public with sharing class FinanceMessageController {

    // Placeholder until Custom Metadata lookup is in place. Skylar to confirm
    // recipient; this likely becomes a multi-address list.
    private static final String FINANCE_EMAIL = 'finance@modernfamilylaw.com';

    @AuraEnabled
    public static String sendFinanceMessage(Map<String, Object> form) {
        try {
            // ── Validation ──────────────────────────────────────────────
            String subject = stringFrom(form, 'subject');
            String message = stringFrom(form, 'message');
            if (String.isBlank(subject))  { throw new InputException('Subject is required.'); }
            if (String.isBlank(message))  { throw new InputException('Message is required.'); }

            String matterId = stringFrom(form, 'matterId'); // optional

            // Single relationship query off User — avoids a separate User→AccountId
            // lookup followed by an Account query.
            User u = [
                SELECT AccountId, Account.Id, Account.Name, Account.PersonEmail
                FROM User WHERE Id = :UserInfo.getUserId() LIMIT 1
            ];
            Account acct = u.Account;
            Id accountId = u.AccountId;

            // ── Send email ─────────────────────────────────────────────
            Messaging.SingleEmailMessage email = new Messaging.SingleEmailMessage();
            email.setToAddresses(new String[] { FINANCE_EMAIL });
            email.setReplyTo(acct.PersonEmail);
            email.setSenderDisplayName('MFL Portal — ' + acct.Name);
            email.setSubject('[Portal Finance] ' + subject);
            email.setPlainTextBody(buildEmailBody(acct, matterId, message));

            // saveAsActivity=false because we log our own Task below (and the
            // standard EmailMessage activity would be on the wrong record).
            Messaging.SendEmailResult[] results =
                Messaging.sendEmail(new Messaging.SingleEmailMessage[] { email }, false);

            if (!results.isEmpty() && !results[0].isSuccess()) {
                throw new InputException('Email send failed: ' + results[0].getErrors()[0].getMessage());
            }

            // ── Log Task so it appears in Recent Updates ──────────────
            Task t = new Task(
                Subject     = 'Finance Inquiry: ' + subject,
                Type        = 'Finance Inquiry',
                Status      = 'Completed',
                Priority    = 'Normal',
                ActivityDate= Date.today(),
                Description = message,
                WhatId      = String.isBlank(matterId) ? accountId : (Id) matterId,
                WhoId       = null
            );
            insert t;

            return 'OK';
        } catch (InputException ie) {
            // User-visible validation error — bubble up cleanly.
            throw new AuraHandledException(ie.getMessage());
        } catch (Exception e) {
            Utility.createFutureErrorRecord(
                e.getMessage(), e.getStackTraceString(), e.getLineNumber(),
                e.getTypeName(), 'FinanceMessageController.sendFinanceMessage'
            );
            throw new AuraHandledException('Could not send your message: ' + e.getMessage());
        }
    }

    private static String buildEmailBody(Account acct, String matterId, String message) {
        String body = '';
        body += 'Client: ' + acct.Name + '\n';
        body += 'Email:  ' + (acct.PersonEmail == null ? '(not on file)' : acct.PersonEmail) + '\n';
        if (String.isNotBlank(matterId)) { body += 'Matter: ' + matterId + '\n'; }
        body += '\n--- Message ---\n' + message + '\n';
        body += '\nSent via MFL Client Portal.';
        return body;
    }

    private static String stringFrom(Map<String, Object> m, String key) {
        if (m == null || !m.containsKey(key) || m.get(key) == null) return '';
        return String.valueOf(m.get(key)).trim();
    }

    public class InputException extends Exception {}
}