public class CG_DateChangeUtils {
    /*
        Finds the day of the week for a given date.
        This will return an integer between 0 and 6.
        0 = Sunday
        1 = Monday
        .
        .
        .
        6 = Saturday
    */
    public static Integer getDayOfWeek(Date d) {
        return Math.mod(Date.newInstance(1900, 1, 7).daysBetween(d), 7);
    } 

    /*
        Takes a date as a parameter which is used to determine the year to calculate the holidays
        Calculates the dated for all relevant holidays. 
        It will calculate the holiday for the following year if the holiday has already passed this year.
    */
    public static Map<String, Date> getHolidayDates(Date today) {
        Map<String, Date> holidayDateMap = new Map<String, Date>();
        //New Year - First day of the year
        Date newYear = Date.newInstance(today.Year(), 1, 1);
        
        //if date is in the past, add a year.
        if(newYear < today) {
            newYear = newYear.addYears(1);
        }

        holidayDateMap.put('New Year', newYear);

        //MLK Day - Third Monday of January
        Date mlkDay = getNthDayOfNthWeek(1, 3, 1, today.Year());

        if(mlkDay < today) {
            mlkDay = getNthDayOfNthWeek(1, 3, 1, today.Year() + 1);
        }

        holidayDateMap.put('MLK Day', mlkDay);

        //Washington-Lincoln Day - Third Monday of February
        Date wlDay = getNthDayOfNthWeek(1, 3, 2, today.Year());

        if(wlDay < today) {
            wlDay = getNthDayOfNthWeek(1, 3, 2, today.Year() + 1);
        }

        holidayDateMap.put('Wash-Lin Day', wlDay);

        //Memorial Day - Last Monday in May
        Date mDay = getNthDayOfNthWeek(1, 5, 5, today.Year());

        if(mDay < today) {
            mDay = getNthDayOfNthWeek(1, 5, 5, today.Year() + 1);
        }

        holidayDateMap.put('Memorial Day', mDay);    

        //Independence Day - 4th of July
        Date indDay = Date.newInstance(today.Year(), 7, 4);
        
        //if date is in the past, add a year.
        if(indDay < today) {
            indDay = indDay.addYears(1);
        }

        holidayDateMap.put('Independence Day', indDay);

        //Labor Day - First Monday in September
        Date labDay = getNthDayOfNthWeek(1, 1, 9, today.Year());

        if(labDay < today) {
            labDay = getNthDayOfNthWeek(1, 1, 9, today.Year() + 1);
        }

        holidayDateMap.put('Labor Day', labDay);
        
        //Columbus Day - Second Monday in October
        Date colDay = getNthDayOfNthWeek(1, 2, 10, today.Year());
    
        if(colDay < today) {
            colDay = getNthDayOfNthWeek(1, 2, 10, today.Year() + 1);
        }

        holidayDateMap.put('Columbus Day', colDay);

        //Veteran's Day - November 11
        Date vDay = Date.newInstance(today.Year(), 11, 11);
        
        //if date is in the past, add a year.
        if(vDay < today) {
            vDay = newYear.addYears(1);
        }

        //Thanksgiving - Fourth Thursday in November
        Date thankDay = getNthDayOfNthWeek(4, 4, 11, today.Year());

        if(thankDay < today) {
            thankDay = getNthDayOfNthWeek(4, 4, 11, today.Year() + 1);
        }

        holidayDateMap.put('Thanksgiving Day', thankDay);

        //Christmas Day - December 25
        Date chrDay = Date.newInstance(today.Year(), 12, 25);

        if(chrDay < today) {
            chrDay = chrDay.addYears(1);
        }

        holidayDateMap.put('Christmas Day', chrDay);

        return holidayDateMap;
    }

    /*
        Gets the date for a holiday that does not have a set date. 
        e.g. Martin Luther King Day - Third Monday of January
        Parameters:
        day -> Integer for the day of the week. 0 = Sunday ... 6 = Saturday
        week -> Integer for the week of the month (1 - 5). Use 5 for the last week.
        month -> Integer for the month.
        year -> which year the holiday wants to be calculated for.
    */
    public static Date getNthDayOfNthWeek(Integer day, Integer week, Integer month, Integer year) {
        //Use 1 for first week and 5 for last week
        Date firstOfMonth; //Will contain the first date of the month
        Integer dayFirstOfMonth; //The day of the week for the first day of the month
        Integer dayChange; //Days to be added to the first of the month to get to the first occurrence of day from holiday
        Integer remainingWeeks; //How many more weeks need to be added to the date
        Date dateOfHoliday; // Final Date

        //Set initial values
        firstOfMonth = Date.newInstance(year, month, 1);
        dayFirstOfMonth = getDayOfWeek(firstOfMonth);
        dayChange = 0;
        remainingWeeks = 0;

        //Determine the number of days to adjust the first of the month to get to the first time the day for the holiday shows up
        if(day > dayFirstOfMonth) {
            dayChange = day - dayFirstOfMonth;
        } else if(day < dayFirstOfMonth) {
            dayChange = 7 - dayFirstOfMonth + 1; //get days until the beginning of next week.
        }
        //If days are equal, dayChange will stay at 0.

        //Add dayChange to first of month
        dateOfHoliday = firstOfMonth + dayChange;

        //Multiply remaining weeks to needed occurrence by 7 to get the number of days to be added to the date.
        remainingWeeks = (week - 1) * 7;

        //Add days to final date
        dateOfHoliday = dateOfHoliday + remainingWeeks;

        //go back a week if the date has moved to the next month.
        while(dateOfHoliday.Month() > month) {
            dateOfholiday = dateOfHoliday - 7;
        }

        return dateOfHoliday;
    }

    //Calculates the next valid date (not saturday, Sunday or Holiday) depending on the due date
    public static Date getValidDate(Date linkedDate, Integer dayDiff) {
        
        Integer dayOfWeek;
        Date dueDate; //New due date
        Map<String, Date> holidayMap = new Map<String, Date>();

        //get the due date and day of the week for the due date
        dueDate = linkedDate + dayDiff;
        dayOfWeek = getDayOfWeek(dueDate);
        //Get holiday dates
        holidayMap = getHolidayDates(dueDate);

        //Check if date is valid, if not, modify and check again
        while(dayOfWeek == 6 || dayOfWeek == 0 || holidayMap.values().contains(dueDate)) { //Saturday or Sunday
            //If date is after linked date, use next due date (Monday if not a holiday)
            if(dayDiff >= 0){
                dueDate += 1;
            }else if(dayDiff < 0) {
                dueDate -= 1;
            }
            dayOfWeek = getDayOfWeek(dueDate);
        }
        return dueDate;
    }

    public static Set<String> getLinkedFieldSet() {

        String linkedFields = '';
        List<String> linkedFieldList = new List<String>();
        Set<String> linkedFieldSet = new Set<String>();

        Auto_Date_Change_Config__c config = Auto_Date_Change_Config__c.getOrgDefaults();

        //Add all fields to a string
        if(config.Tracked_Fields_1__c != null) {
            linkedFields += config.Tracked_Fields_1__c.removeEnd(',');
        }
        if(config.Tracked_Fields_2__c != null) {
            if(config.Tracked_Fields_1__c != null){
                linkedFields += ',';
            }
            linkedFields += config.Tracked_Fields_2__c.removeEnd(',');
        }
        if(config.Tracked_Fields_3__c != null) {
            if(config.Tracked_Fields_1__c != null || config.Tracked_Fields_2__c != null){
                linkedFields += ',';
            }
            linkedFields += config.Tracked_Fields_3__c.removeEnd(',');
        }

        //Make string into a list
        linkedFieldList = linkedFields.split(',');

        //Add items form list to a set
        for(String s : linkedFieldList){
            if(s != '' || s != null || s != ' ') {
                linkedFieldSet.add(s.trim());
            }
        }

        return linkedFieldSet;
    }
}