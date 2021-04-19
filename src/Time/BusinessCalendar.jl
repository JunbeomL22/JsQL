import Dates: adjust
abstract type BusinessCalendar end
#
struct TargetCalendar <: BusinessCalendar end
struct NullCalendar <: BusinessCalendar end
#
abstract type WesternCalendar <: BusinessCalendar end
abstract type EasternCalendar <: BusinessCalendar end
#
abstract type UnitedStatesCalendar <: WesternCalendar end
abstract type UnitedKingdomCalendar <: WesternCalendar end
abstract type EuroCalendar <: WesternCalendar end
#

abstract type SouthKoreaCalendar <: EasternCalendar end
#abstract type HongKongCalendar <: EasternCalendar end
#abstract type JapanCalendar <: EasternCalendar end

mutable struct JointCalendar{B <: BusinessCalendar, C <: BusinessCalendar} <: BusinessCalendar
    cal1::B
    cal2::C
end

abstract type BusinessDayConvention end
struct Unadjusted <: BusinessDayConvention end
struct ModifiedFollowing <: BusinessDayConvention end
struct Following <: BusinessDayConvention end
# The following types have not be used
struct Preceding <: BusinessDayConvention end
struct ModifiedPreceding <: BusinessDayConvention end


function JointCalendar(cals...)
    length(cals) < 2 && error("more than one calendar is needed for JointCalendar")

    cal = JointCalendar(cals[1], cals[2])
    if length(cals) > 2
        for i = 3:length(cals)
            cal = JointCalendar(cal, cals[i])
        end
    end
    return cal
end

# easter functions
function easter_rata(y::Int)
    local c::Int64
    local e::Int64
    local p::Int64
  
     # Algo R only works after 1582
    if y < 1582
        # Are you using this? Send me a postcard!
        error("Year cannot be less than 1582. Provided: $(y).")
    end
  
    # Century
    c = div( y , 100) + 1
  
    # Shifted Epact
    e = mod(14 + 11*(mod(y, 19)) - div(3*c, 4) + div(5+8*c, 25), 30)
  
    # Adjust Epact
    if (e == 0) || ((e == 1) && ( 10 < mod(y, 19) ))
        e += 1
    end
  
    # Paschal Moon
    p = Date(y, 4, 19).instant.periods.value - e
  
    # Easter: locate the Sunday after the Paschal Moon
    return p + 7 - mod(p, 7)
end
  
# Returns Date
function easter_date(y::Int)
    # Compute the gregorian date for Rata Die number
    return Date(Dates.rata2datetime( easter_rata(y) ))
end

"""
This push the date to the direction NOT considering businessday convention. \n
With the Dates.Day (as the first argument) and without convention, \n
    we use this functino only for moving the date \n
For example, say \n
d = Date(2020, 12, 16)\n
calendar = NullCalendar()\n
advance(Day(-3), calendar, d) => 2020-12-11\n
advance(Day(3), calendar, d)  => 2020-12-21
"""
function advance(days::Day, cal::BusinessCalendar, dt::Date)
    n = days.value
    if n > 0
      while n > 0
        dt += Day(1)
        while !is_business_day(cal, dt)
          dt += Day(1)
          
        end
        n -= 1
      end
    else
      while (n < 0)
        dt -= Day(1)
        while !is_business_day(cal, dt)
          dt -= Day(1)
        end
        n += 1
      end
    end
  
    return dt
end

function advance(time_period::Union{Day, Week, Month, Year}, cal::BusinessCalendar, dt::Date, biz_conv::BusinessDayConvention)
    # move the date w.o. convention
    dt += time_period
    # now consider the convention by the following function:
    return adjust(cal, biz_conv, dt)
end
adjust(::BusinessCalendar, bdc::BusinessDayConvention, d::Date) = error("undefined for $(typeof(bdc))")

adjust(::BusinessCalendar, ::Unadjusted, d::Date) = d

function adjust(cal::BusinessCalendar, ::Following, d::Date)
    while !is_business_day(cal, d)
        d += Day(1)
    end
    return d
end
function adjust(cal::BusinessCalendar, ::ModifiedFollowing, d::Date)
    x = d
    while !is_business_day(cal, x)
        x += Day(1)
    end
    
    if Month(x) != Month(d)  
        return advance(Day(-1), cal, x)
    else
   
        return x
    end
end

adjust(cal::BusinessCalendar, d::Date) = adjust(cal, Following(), d)

is_business_day(cal::NullCalendar, ::Date) = true
is_weekend(dt::Date) = dayofweek(dt) in [6, 7]

function is_business_day(cal::BusinessCalendar, dt::Date)
    if is_weekend(dt) || is_holiday(cal, dt)
        return false
    else
        return true
    end
end

# In the United States, if a holiday falls on Saturday, it's observed on the preceding Friday.
# If it falls on Sunday, it's observed on the next Monday.
function adjustweekendholidayUS(dt::Date)
	if dayofweek(dt) == 6
		return dt - Dates.Day(1)
	end
	if dayofweek(dt) == 7
		return dt + Dates.Day(1)
	end
	return dt
end

is_holiday(joint::JointCalendar, dt::Date) = is_holiday(joint.cal1, dt) || is_holiday(joint.cal2, dt)

function is_holiday(::TargetCalendar, dt::Date)
    yy = year(dt)
    mm = month(dt)
    dd = day(dt)
    easter_sun = easter_date(yy)
  
    if (
        # New Years Day
        (mm == 1 && dd == 1)
        #||
        # Good Friday
        #easter_sun - Day(2) == dt
        #||
        # Easter Monday
        #easter_sun + Day(1) == dt
        #||
        # Int'l Labor Day
        #(mm == 5 && dd == 1)
        ||
        # Christmas
        (mm == 12 && dd == 25)
        #||
        # Day of Goodwill
        #(mm == 12 && dd == 26)
        )
        return true
    else
        return false
    end
end

function is_endofmonth(d::Date)
    return d == lastdayofmonth(d)
end