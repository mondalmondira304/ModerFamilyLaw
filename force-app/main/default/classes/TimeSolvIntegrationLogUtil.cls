/**
 * @description Utility class for handling TimeSolv integration logging
 * @author Sanders
 * @date 2025-04-18
 */
public class TimeSolvIntegrationLogUtil {
    //─────────────────────────────────
    // Log‐type constants
    //─────────────────────────────────
    public static final String LOG_TYPE_ERROR   = 'Error';
    public static final String LOG_TYPE_WARNING = 'Warning';

    //─────────────────────────────────
    // Integration‐type constants
    //─────────────────────────────────
    public static final String INTEGRATION_TYPE_MATTER             = 'Matter Creation';
    public static final String INTEGRATION_TYPE_CONTACT            = 'Contact Creation';
    public static final String INTEGRATION_TYPE_CLIENT             = 'Client Creation';
    public static final String INTEGRATION_TYPE_TOKEN              = 'Token Retrieval';
    public static final String INTEGRATION_TYPE_RETAINER           = 'Retainer Invoice Creation';
    public static final String INTEGRATION_TYPE_TRUST              = 'Trust Account Creation';
    public static final String INTEGRATION_TYPE_ASSOCIATION        = 'Contact Association';
    public static final String INTEGRATION_TYPE_CHECK_TRUST_ACC    = 'Check Trust Account Balance';
    public static final String INTEGRATION_TYPE_ZERO_TRUST_BALANCE = 'Zero Trust Balance';

    //─────────────────────────────────
    // In-memory buffer of logs
    //─────────────────────────────────
    private static List<TimeSolv_Integration_Log__c> pendingLogs = new List<TimeSolv_Integration_Log__c>();

    /**
     * Log an error entry
     */
    public static TimeSolv_Integration_Log__c logError(
        Id    accountId,
        String integrationType,
        String message,
        Exception e
    ) {
        return createLog(
            accountId,
            LOG_TYPE_ERROR,
            integrationType,
            message,
            (e != null ? e.getStackTraceString() : null)
        );
    }

    /**
     * Log a warning entry
     */
    public static TimeSolv_Integration_Log__c logWarning(
        Id    accountId,
        String integrationType,
        String message
    ) {
        return createLog(
            accountId,
            LOG_TYPE_WARNING,
            integrationType,
            message,
            null
        );
    }

    private static TimeSolv_Integration_Log__c createLog(
        Id    accountId,
        String type,
        String integrationType,
        String message,
        String stackTrace
    ) {
        TimeSolv_Integration_Log__c log = new TimeSolv_Integration_Log__c(
            Account__c          = accountId,
            Type__c             = type,
            Integration_Type__c = integrationType,
            Message__c          = message,
            Stack_Trace__c      = stackTrace,
            Timestamp__c        = Datetime.now()
        );
        pendingLogs.add(log);
        return log;
    }

    /**
     * Clears in-memory log buffer.
     */
    public static void clearPendingLogs() {
        pendingLogs.clear();
    }

    /**
     * Persists all pending logs (Errors & Warnings only).
     */
    public static Database.SaveResult[] savePendingLogs() {
        if (pendingLogs.isEmpty()) {
            return new List<Database.SaveResult>();
        }
        List<TimeSolv_Integration_Log__c> toInsert = new List<TimeSolv_Integration_Log__c>(pendingLogs);
        pendingLogs.clear();
        return Database.insert(toInsert, false);
    }

    /**
     * Utility to extract messages from DML errors.
     */
    public static List<String> getErrorMessages(List<Database.Error> errors) {
        List<String> msgs = new List<String>();
        for (Database.Error err : errors) {
            msgs.add(err.getStatusCode() + ': ' + err.getMessage());
        }
        return msgs;
    }

    /**
     * Build a Task record from an error or warning log.
     */
    public static Task createTaskFromLog(TimeSolv_Integration_Log__c log) {
        if (log == null) {
            return null;
        }

        String line1 = 'Integration Type: ' + log.Integration_Type__c;
        String line2 = '\nMessage: '      + log.Message__c;
        String line3 = log.Stack_Trace__c != null
            ? '\n\nStack Trace:\n' + log.Stack_Trace__c
            : '';

        String fullDesc = line1 + line2 + line3;

        Task t = new Task(
            WhatId       = log.Account__c,
            Subject      = 'TimeSolv ' + log.Type__c + ': ' + log.Integration_Type__c,
            Status       = (log.Type__c == LOG_TYPE_ERROR) ? 'Not Started' : 'Completed',
            Priority     = (log.Type__c == LOG_TYPE_ERROR) ? 'High'        : 'Normal',
            Type         = 'Other',
            ActivityDate = Date.today(),
            Description  = fullDesc
        );
        return t;
    }
}