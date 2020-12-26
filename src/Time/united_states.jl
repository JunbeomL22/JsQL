struct USSettlementCalendar <: UnitedStatesCalendar end
struct USGovernmentBondCalendar <: UnitedStatesCalendar end
struct USNYSECalendar <: UnitedStatesCalendar end

function is_holiday(::USSettlementCalendar, dt::Date)
	yy = year(dt)
	mm = month(dt)
	dd = day(dt)

	if (
		# New Year's Day
        adjustweekendholidayUS(Date(yy, 1, 1)) == dt
        ||
        # New Year's Day on the previous year when 1st Jan is Saturday
        (mm == 12 &&  dd == 31 && dayofweek(dt) == Friday)
        ||
        # Birthday of Martin Luther King, Jr.
        (dayofweek(dt) == 1 && dayofweekofmonth(dt) ==3 && mm == 1)
        ||
        # Washington's Birthday
        (dayofweek(dt) == 1 && dayofweekofmonth(dt) ==3 && mm == 2)
        ||
        # Memorial Day is the last Monday in May
        (dayofweek(dt) == 1 && dayofweekofmonth(dt) == daysofweekinmonth(dt) && mm == 5)
        ||
        # Independence Day
        adjustweekendholidayUS(Date(yy, 7, 4)) == dt
        ||
        # Labor Day is the first Monday in September
        (dayofweek(dt) == 1 && dayofweekofmonth(dt) == 1 && mm == 9)
        ||
        # Columbus Day is the second Monday in October
        (dayofweek(dt) == 1 && dayofweekofmonth(dt) == 2 && mm == 10)
        ||
        # Veterans Day
        adjustweekendholidayUS(Date(yy, 11, 11)) == dt
        ||
        # Thanksgiving Day is the fourth Thursday in November
        (dayofweek(dt) == 4 && dayofweekofmonth(dt) == 4 && mm == 11)
        ||
        # Christmas
        adjustweekendholidayUS(Date(yy, 12, 25)) == dt
        )
		return true
	end

	return false
end

function is_holiday(::USGovernmentBondCalendar, dt::Date)
    yy = year(dt)
    mm = month(dt)
    dd = day(dt)
    if (
        # New Year's Day
        adjustweekendholidayUS(Date(yy, 1, 1)) == dt
        ||
        # New Year's Day on the previous year when 1st Jan is Saturday
        (mm == 12 &&  dd == 31 && dayofweek(dt) == Friday)
        ||
        # Birthday of Martin Luther King, Jr.
        (dayofweek(dt) == 1 && dayofweekofmonth(dt) ==3 && mm == 1)
        ||
        # Washington's Birthday
        (dayofweek(dt) == 1 && dayofweekofmonth(dt) ==3 && mm == 2)
        ||
        # Good Friday
        easter_date(yy) - Day(2) == dt
        ||
        # Memorial Day is the last Monday in May
        (dayofweek(dt) == 1 && dayofweekofmonth(dt) == daysofweekinmonth(dt) && mm == 5)
        ||
        # Independence Day
        adjustweekendholidayUS(Date(yy, 7, 4)) == dt
        ||
        # Labor Day is the first Monday in September
        (dayofweek(dt) == 1 && dayofweekofmonth(dt) == 1 && mm == 9)
        ||
        # Columbus Day is the second Monday in October
        (dayofweek(dt) == 1 && dayofweekofmonth(dt) == 2 && mm == 10)
        ||
        # Veterans Day
        adjustweekendholidayUS(Date(yy, 11, 11)) == dt
        ||
        # Thanksgiving Day is the fourth Thursday in November
        (dayofweek(dt) == 4 && dayofweekofmonth(dt) == 4 && mm == 11)
        ||
        # Christmas
        adjustweekendholidayUS(Date(yy, 12, 25)) == dt
        )
        return true
    end
  
    return false
end

function is_holiday(::USNYSECalendar, dt::Date)
    yy = year(dt)
    mm = month(dt)
    dd = day(dt)
    if (
        # New Year's Day
        adjustweekendholidayUS(Date(yy, 1, 1)) == dt
        ||
        # New Year's Day on the previous year when 1st Jan is Saturday
        (mm == 12 &&  dd == 31 && dayofweek(dt) == Friday)
        ||
        # Birthday of Martin Luther King, Jr.
        (dayofweek(dt) == 1 && dayofweekofmonth(dt) ==3 && mm == 1)
        ||
        # Washington's Birthday
        (dayofweek(dt) == 1 && dayofweekofmonth(dt) ==3 && mm == 2)
        ||
        # Good Friday
        easter_date(yy) - Day(2) == dt
        ||
        # Memorial Day is the last Monday in May
        (dayofweek(dt) == 1 && dayofweekofmonth(dt) == daysofweekinmonth(dt) && mm == 5)
        ||
        # Independence Day
        adjustweekendholidayUS(Date(yy, 7, 4)) == dt
        ||
        # Labor Day is the first Monday in September
        (dayofweek(dt) == 1 && dayofweekofmonth(dt) == 1 && mm == 9)
        ||
        # Thanksgiving Day is the fourth Thursday in November
        (dayofweek(dt) == 4 && dayofweekofmonth(dt) == 4 && mm == 11)
        ||
        # Christmas
        adjustweekendholidayUS(Date(yy, 12, 25)) == dt
        )
        return true
    end
  
    # Special Closings
    if (
        # Hurricane Sandy
        (yy == 2012 && mm == 10 && dd in (29, 30))
        ||
        # President Ford's funeral
        (yy == 2007 && mm == 1 && dd == 2)
        ||
        # President Reagan's funeral
        (yy == 2004 && mm == 6 && dd == 11)
        ||
        # 9/11
        (yy == 2001 && mm == 9 && dd in (11, 12, 13, 14))
        )
        return true
    end
  
    return false
end