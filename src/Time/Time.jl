module Time

using Dates
import Dates.adjust

# Date helper function
# just curious. Is it that useful?
within_next_week(d1::Date, d2::Date) = d1 <= d2 <= d1 + Dates.Day(7)
within_next_week(t1::Float64, t2::Float64) = t1 <= t2 <= t1 + 1.0/52.0
within_previous_week(d1::Date, d2::Date) = d1-Dates.Day(7)<= d2 <= d1
within_previous_week(t1::Float64, t2::Float64) = t1 - 1.0/52.0<= t2 <= t1

export 
within_next_week, within_next_week, within_next_week, within_next_week

export # frequency.jl
Frequency, NoFrequency, Once, Annual, SemiAnnual, EveryFourthMonth,
Quaterly, Monthly, Weekly, Daily, Biweekly, EveryFourthMonth, EveryFourthWeek, Bimonthly


export # day_count.jl
DayCount, Act360, Act365, day_count, days_per_year, year_fraction, IsdaActAct

export # BusinessCalendar.jl
BusinessCalendar, WesternCalendar, KoreaCalendar, JointCalendar,
easter_date, easter_rata, advance, adjust, 
BusinessDayConvention, Unadjusted, ModifiedFollowing, Following, Preceding, ModifiedPreceding,
is_holiday, is_endofmonth, is_business_day,
# south_korea.jl
NullCalendar, SouthKoreaKrxCalendar, SouthKoreaSettlementCalendar, 
# united_states.jl
USNYSECalendar, USSettlementCalendar, USGovernmentBondCalendar, 
# united_kingdom.jl
UKLSECalendar, UKSettlementCalendar

export # tenor_period.jl
TenorPeriod

export # schedule.jl
DateGenerationRule, DateGenerationForwards, DateGenerationBackwards, DateGenerationTwentieth, 
Schedule

export # time_grid.jl
TimeGrid, DateTimeGrid, is_empty, closest_time, return_index

include("Frequency.jl")
include("DayCount.jl")
include("BusinessCalendar.jl")
include("south_korea.jl")
include("united_states.jl")
include("united_kingdom.jl")
include("tenor_period.jl")
include("schedule.jl")
include("time_grid.jl")

end