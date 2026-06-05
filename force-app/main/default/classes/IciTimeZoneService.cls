/**
 * @description
 * Converts an Account DateTime (entered in the editor's local timezone) into a UTC DateTime
 * that represents the SAME wall time in the attorney's OFFICE timezone (derived from office name).
 *
 * Example:
 * - Someone in Denver enters 11:00 AM.
 * - Attorney office is Oakland (Pacific).
 * - Event should be 11:00 AM Pacific (which is 12:00 PM Denver).
 *
 * No new fields required. Requires office name values to map to IANA tz.
 *
 * @author  Sanders
 * @date    2026-02-09
 */
public with sharing class IciTimeZoneService {

    public class ConversionException extends Exception {}

    public class Request {
        @InvocableVariable(required=true)
        public Datetime storedMeetingDateTime; // $Record.ICI_Date_Time__c

        @InvocableVariable(required=true)
        public Id enteredByUserId;             // $Record.LastModifiedById (or $User.Id)

        @InvocableVariable(required=true)
        public String attorneyOfficeName;      // e.g., "Oakland", "Denver", "Dallas"

        @InvocableVariable(required=false)
        public Integer durationMinutes;        // default 60
    }

    public class Response {
        @InvocableVariable public Datetime startUtc;
        @InvocableVariable public Datetime endUtc;

        @InvocableVariable public String enteredByTimeZone;
        @InvocableVariable public String officeTimeZone;
    }

    @InvocableMethod(
        label='Convert ICI Meeting Time to UTC'
        description='Converts editor-entered ICI time to attorney-office wall time (UTC) for Event Start/End.'
    )
    public static List<Response> convertToUtc(List<Request> requests) {
        List<Response> results = new List<Response>();
        if (requests == null || requests.isEmpty()) return results;

        // Lookup editor timezones (kept for compatibility; output only)
        Set<Id> userIds = new Set<Id>();
        for (Request r : requests) {
            if (r != null && r.enteredByUserId != null) userIds.add(r.enteredByUserId);
        }

        Map<Id, User> usersById = new Map<Id, User>();
        if (!userIds.isEmpty()) {
            usersById = new Map<Id, User>([
                SELECT Id, TimeZoneSidKey
                FROM User
                WHERE Id IN :userIds
            ]);
        }

        for (Request r : requests) {
            Response out = new Response();
            results.add(out);

            if (r == null || r.storedMeetingDateTime == null) continue;

            Integer mins = (r.durationMinutes == null || r.durationMinutes <= 0) ? 60 : r.durationMinutes;

            // Keep enteredByTimeZone populated (do not use it for conversion anymore)
            User editor = (r.enteredByUserId != null) ? usersById.get(r.enteredByUserId) : null;
            if (editor != null && !String.isBlank(editor.TimeZoneSidKey)) {
                out.enteredByTimeZone = editor.TimeZoneSidKey.trim();
            }

            if (String.isBlank(r.attorneyOfficeName)) {
                throw new ConversionException('Missing attorneyOfficeName (office name).');
            }

            String officeTz = officeNameToIana(r.attorneyOfficeName);
            if (String.isBlank(officeTz)) {
                throw new ConversionException('Unmapped office name: ' + r.attorneyOfficeName);
            }

            // Treat the stored Account DateTime as OFFICE wall time, regardless of who edited it.
            String wallStamp = r.storedMeetingDateTime.format('yyyy-MM-dd HH:mm:ss', officeTz);

            // Convert OFFICE wall time -> UTC
            Datetime startUtc = localWallTimeToUtc(wallStamp, officeTz);
            Datetime endUtc   = startUtc.addMinutes(mins);

            out.startUtc = startUtc;
            out.endUtc = endUtc;
            out.officeTimeZone = officeTz;
        }

        return results;
    }

    /**
     * @description Map MFL office names to IANA timezone IDs (DST-safe).
     */
    private static String officeNameToIana(String officeNameRaw) {
        String n = officeNameRaw == null ? '' : officeNameRaw.trim().toLowerCase();

        // Pacific
        if (n == 'bellevue' || n == 'everett' || n == 'oakland' || n == 'palo alto' || n == 'san jose' || n == 'seattle') {
            return 'America/Los_Angeles';
        }

        // Mountain
        if (n == 'fort collins' || n == 'colorado springs' || n == 'denver') {
            return 'America/Denver';
        }

        // Central
        if (n == 'dallas' || n == 'san antonio' || n == 'austin') {
            return 'America/Chicago';
        }

        // Eastern
        if (n == 'atlanta') {
            return 'America/New_York';
        }

        return null;
    }

    /**
     * @description Converts a "yyyy-MM-dd HH:mm:ss" wall time in a given timezone to a UTC Datetime.
     */
    private static Datetime localWallTimeToUtc(String wallStamp, String tzId) {
        Datetime gmtGuess = Datetime.valueOfGmt(wallStamp);

        TimeZone tz = TimeZone.getTimeZone(tzId);
        if (tz == null) {
            throw new ConversionException('Invalid timezone id: ' + tzId);
        }

        Integer offsetMs  = tz.getOffset(gmtGuess);
        Integer offsetSec = offsetMs / 1000;
        return gmtGuess.addSeconds(-offsetSec);
    }
}