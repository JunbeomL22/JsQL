module Times

import Dates.Date


# Date helper function
# just curious. Is it that useful?
within_next_week(d1::Date, d2::Date) = d1 <= d2 <= d1 + Dates.Day(7)
within_next_week(t1::Float64, t2::Float64) = t1 <= t2 <= t1 + 1.0/52.0
within_previous_week(d1::Date, d2::Date) = d1-Dates.Day(7)<= d2 <= d1
within_previous_week(t1::Float64, t2::Float64) = t1 - 1.0/52.0<= t2 <= t1

export 
within_next_week, within_next_week, within_next_week, within_next_week

# frequency.jl
export Frequency, NoFrequency, Once, Annual, SemiAnnual, EveryFourthMonth,
Quaterly, Monthly, Weekly, Daily

# day_count.jl
export DayCount, Act360, Act365, day_count, days_per_year, year_fraction

export BusinessCalendar, WesternCalendar, KoreaCalendar, 
easter_date, easter_rata, advance, adjust,
SouthKoreaKrxCalendar, SouthKoreaSettlementCalendar, USNYSECalendar, USSettlementCalendar, 
USGovernmentBondCalendar, is_holiday

include("Frequency.jl")
include("DayCount.jl")
include("BusinessCalendar.jl")
include("south_korea.jl")
include("united_states.jl")

end