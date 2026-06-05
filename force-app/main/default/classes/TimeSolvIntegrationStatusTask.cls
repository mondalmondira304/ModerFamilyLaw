/**
 * @description Utility class for creating and updating consolidated TimeSolv integration status tasks
 * @author Sanders
 * @date 2025-04-20
 */
public class TimeSolvIntegrationStatusTask {
    
    /**
     * @description Creates or updates a consolidated integration task on the account
     * @param acc Account record
     * @param stage Current integration stage name
     * @param status Success, Warning, or Error
     * @param message Details about the step
     * @param logId Related log ID
     */
    public static void updateIntegrationStatusTask(
        Account acc, 
        String stage, 
        String status, 
        String message,
        Id logId
    ) {
        // Look for existing integration task
        List<Task> existingTasks = [
            SELECT Id, Description, Status
            FROM Task 
            WHERE WhatId = :acc.Id 
            AND Subject = 'TimeSolv Integration Status'
            AND ActivityDate = TODAY
            LIMIT 1
        ];
        
        Task statusTask;
        if (!existingTasks.isEmpty()) {
            // Update existing task
            statusTask = existingTasks[0];
        } else {
            // Create new task
            statusTask = new Task(
                Subject = 'TimeSolv Integration Status',
                WhatId = acc.Id,
                Status = 'In Progress',
                Priority = 'Normal',
                ActivityDate = Date.today()
            );
        }
        
        // Format status line with timestamp
        String timestamp = Datetime.now().format('yyyy-MM-dd HH:mm:ss');
        String statusLine = timestamp + ' - ' + stage + ': ' + status;
        if (String.isNotBlank(message)) {
            statusLine += ' - ' + message;
        }
        if (logId != null) {
            statusLine += ' (Log: ' + logId + ')';
        }
        statusLine += '\n\n';
        
        // Update description, append to top
        String currentDescription = statusTask.Description != null ? statusTask.Description : '';
        statusTask.Description = statusLine + currentDescription;
        
        // Update task status based on stage completion/failure
        if (status == 'Error') {
            statusTask.Status = 'Blocked';
        } else if (stage == 'Invoice Retainer' && status == 'Success') {
            statusTask.Status = 'Completed';
        }
        
        upsert statusTask;
    }
}