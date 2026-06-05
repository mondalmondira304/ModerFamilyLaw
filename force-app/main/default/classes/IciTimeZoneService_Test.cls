/**
 * @description
 * Test coverage for IciTimeZoneService.convertToUtc
 *
 * Covers:
 * - Happy path conversion + duration
 * - Default duration (60)
 * - Null request / null datetime -> returns Response with nulls (no exception)
 * - Missing office name -> throws
 * - Unmapped office name -> throws
 *
 * Notes:
 * - Uses running user as enteredByUserId to avoid creating Users.
 */
@IsTest
private class IciTimeZoneService_Test {

    private static IciTimeZoneService.Request req(Datetime dt, String office, Integer mins) {
        IciTimeZoneService.Request r = new IciTimeZoneService.Request();
        r.storedMeetingDateTime = dt;
        r.enteredByUserId       = UserInfo.getUserId();
        r.attorneyOfficeName    = office;
        r.durationMinutes       = mins;
        return r;
    }

    @IsTest
    static void happyPath_pacific_setsUtcAndDuration() {
        // Pick a deterministic wall time. 
        Datetime stored = Datetime.newInstance(2026, 2, 11, 11, 0, 0);

        Test.startTest();
        List<IciTimeZoneService.Response> res =
            IciTimeZoneService.convertToUtc(new List<IciTimeZoneService.Request>{
                req(stored, 'Oakland', 30)
            });
        Test.stopTest();

        System.assertEquals(1, res.size());
        System.assertNotEquals(null, res[0].startUtc);
        System.assertNotEquals(null, res[0].endUtc);
        System.assertEquals('America/Los_Angeles', res[0].officeTimeZone);

        // Duration applied
        System.assertEquals(30, (res[0].endUtc.getTime() - res[0].startUtc.getTime()) / (1000 * 60));

        // Round-trip check: startUtc formatted in office tz matches original wall time stamp
        String wallFromUtc = res[0].startUtc.format('yyyy-MM-dd HH:mm:ss', 'America/Los_Angeles');
        String wallStored  = stored.format('yyyy-MM-dd HH:mm:ss', 'America/Los_Angeles');
        System.assertEquals(wallStored, wallFromUtc);

        // EnteredByTimeZone should be present (if user has one)
        System.assertNotEquals(null, res[0].enteredByTimeZone);
    }

    @IsTest
    static void defaultDuration_is60() {
        Datetime stored = Datetime.newInstance(2026, 2, 11, 9, 15, 0);

        List<IciTimeZoneService.Response> res =
            IciTimeZoneService.convertToUtc(new List<IciTimeZoneService.Request>{
                req(stored, 'Denver', null)
            });

        System.assertEquals(1, res.size());
        System.assertEquals('America/Denver', res[0].officeTimeZone);
        System.assertEquals(60, (res[0].endUtc.getTime() - res[0].startUtc.getTime()) / (1000 * 60));
    }

    @IsTest
    static void nullRequestOrNullDatetime_noThrow_returnsNulls() {
        // null request element
        List<IciTimeZoneService.Response> res1 =
            IciTimeZoneService.convertToUtc(new List<IciTimeZoneService.Request>{
                null
            });
        System.assertEquals(1, res1.size());
        System.assertEquals(null, res1[0].startUtc);

        // request with null datetime
        IciTimeZoneService.Request r = req(null, 'Dallas', 10);
        List<IciTimeZoneService.Response> res2 =
            IciTimeZoneService.convertToUtc(new List<IciTimeZoneService.Request>{ r });

        System.assertEquals(1, res2.size());
        System.assertEquals(null, res2[0].startUtc);
        System.assertEquals(null, res2[0].endUtc);
    }

    @IsTest
    static void missingOffice_throws() {
        Datetime stored = Datetime.newInstance(2026, 2, 11, 10, 0, 0);

        try {
            IciTimeZoneService.convertToUtc(new List<IciTimeZoneService.Request>{
                req(stored, null, 60)
            });
            System.assert(false, 'Expected ConversionException for missing office name.');
        } catch (IciTimeZoneService.ConversionException e) {
            System.assert(e.getMessage().contains('Missing attorneyOfficeName'));
        }
    }

    @IsTest
    static void unmappedOffice_throws() {
        Datetime stored = Datetime.newInstance(2026, 2, 11, 10, 0, 0);

        try {
            IciTimeZoneService.convertToUtc(new List<IciTimeZoneService.Request>{
                req(stored, 'Mars Base Alpha', 60)
            });
            System.assert(false, 'Expected ConversionException for unmapped office name.');
        } catch (IciTimeZoneService.ConversionException e) {
            System.assert(e.getMessage().contains('Unmapped office name'));
        }
    }
}