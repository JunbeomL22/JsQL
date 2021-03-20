struct UKLSECalendar <: UnitedKingdomCalendar end
struct UKSettlementCalendar <: UnitedKingdomCalendar end

function is_holiday(c::Union{UKSettlementCalendar, UKLSECalendar}, dt::Date)
    yy = year(dt)
    mm = month(dt)
    dd = day(dt)

    if (
    # New Year's Day
    adjustweekendholidayUK(Date(yy, 1, 1)) == dt
    ||
    # Good Friday
    easter_date(yy) - Day(2) == dt
    ||
    # Easter MONDAY
    easter_date(yy) + Day(1) == dt
    ||
    # first MONDAY of May (Early May Bank Holiday)
    (dayofweek(dt) == 1 && dayofweekofmonth(dt) == 1 && mm == 5)
    ||
    # last MONDAY of MAY (Spring Bank Holiday)
    (dayofweek(dt) == 1 && dayofweekofmonth(dt) == daysofweekinmonth(dt) && mm == 5)
    ||
    # last MONDAY of August (Summer Bank Holiday)
    (dayofweek(dt) == 1 && dayofweekofmonth(dt) == daysofweekinmonth(dt) && mm == 8)
    ||
    # Christmas (possibly moved to MONDAY or Tuesday)
    adjustweekendholidayUK(Date(yy, 12, 25)) == dt
    ||
    # Boxing Day (possibly moved to MONDAY or TUESDAY)
    adjustweekendholidayUK(adjustweekendholidayUK(Date(yy, 12, 25)) + Day(1)) == dt
    )
    return true
    end
  
    # Fixed holidays
    if (
        # Substitute date for Spring Bank Holiday
        (dt == Date(2012, 06, 04))
        ||
        # Diamond Jubilee of Queen Elizabeth II.
        (dt == Date(2012, 06, 05))
        ||
        # Golden Jubilee of Queen Elizabeth II.
        (dt == Date(2002, 06, 03))
        ||
        # Substitute date for Spring Bank Holiday
        (dt == Date(2002, 06, 04))
        ||
        # Wedding of Prince William and Catherine Middleton
        (dt == Date(2011, 04, 29))
      )
      return true
    end
  
    return false
end

