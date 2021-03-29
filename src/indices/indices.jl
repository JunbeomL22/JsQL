using Dates
# Reference: https://quant.opengamma.io/Interest-Rate-Instruments-and-Market-Conventions.pdf
#= 
end of month rule
    Where the start date of a period is on the final business day of a particular calendar month, the end
    date is on the final business day of the end month (not necessarily the corresponding date in the end
    month).
Examples:
    • Start date 28-Feb-2011, period 1 month: end date: 31-Mar-2011.
    • Start date 29-Apr-2011, period 1 month: end date: 31-May-2012. 30-Apr-2011 is a Saturday, so
    29-Apr is the last business day of the month.
    • Start date 28-Feb-2012, period 1 month: end date: 28-Mar-2012. 2012 is a leap year and the 28th
    is not the last business day of the month!
=#

struct IborIndex{TP<: TenorPeriod, CUR <: AbstractCurrency, B <: BusinessCalendar,
    C <: BusinessDayConvention, DC <: DayCount, T <: TermStructure} <: InterestRateIndex
    #
    familyName::String
    tenor::TP
    fixingDays::Int
    currency::CUR
    fixingCalendar::B
    convention::C
    endOfMonth::Bool
    dc::DC
    ts::TermStructure
    pastFixings::Dict{Date, Float64}
end

IborIndex(familyName::String, tenor::TP, fixingDays::Int, 
            currency::CUR, fixingCalendar::B, convention::C, endOfMonth::Bool, dc::DC, ts::T = NullTermStructure(), pastFixings = Dict{Date, Float64}()
            ) where {TP <: TenorPeriod, CUR <: AbstractCurrency, 
                     B <: BusinessCalendar, C <: BusinessDayConvention, DC <: DayCount, T <: TermStructure} = 
                      # equal to 
                      IborIndex{TP, CUR, B, C, DC, T}(familyName, tenor, fixingDays, currency, fixingCalendar, convention, endOfMonth, dc, ts, pastFixings)

"""
For Libor, \n
1) EOM and Modified Following applies \n
2) except EUR & GBP value date = two london business day + fixing date \n
3) except GBP, ACT/360 applies \n
"""
struct LiborIndex{TP<: TenorPeriod, B <: BusinessCalendar,
    C <: BusinessDayConvention, DC <: DayCount, T <: TermStructure} <: InterestRateIndex
    familyName::String
    tenor::TP
    fixingDays::Int
    currency::Currency
    fixingCalendar::B
    jointCalendar::JointCalendar
    dc::DC
    ts::TermStructure
    convention::C
    endOfMonth::Bool
    pastFixings::Dict{Date, Float64}
end

LiborIndex(familyName::String, tenor::TP, fixingDays::Int, currency::Currency, fixingCalendar::B,
            jointCalendar::JointCalendar,  dc::DC,
            ts::T = NullTermStructure(), convention::C = ModifiedFollowing(), 
            endOfMonth::Bool = true, pastFixings = Dict{Date, Float64}()
            ) where {TP <: TenorPeriod, B <: BusinessCalendar, C <: BusinessDayConvention, 
                    DC <: DayCount, T <: TermStructure} =
            # equal to 
            LiborIndex{TP, B, C, DC, T}(familyName, tenor, fixingDays, currency, 
                                        fixingCalendar, jointCalendar, dc, ts, convention, endOfMonth, pastFixings)

function LiborIndex(familyName::String, tenor::TenorPeriod, fixingDays::Int, currency::Currency, 
                    fixingCalendar::BusinessCalendar, dc::DayCount, yts::YieldTermStructure)
    # beginning of the body
    endofMonth = libor_eom(tenor.period)
    conv = libor_conv(tenor.period)
    jc = JointCalendar(JsQL.Time.UKLSECalendar(), fixingCalendar)

    return LiborIndex(familyName, tenor, fixingDays, currency, fixingCalendar, 
                    jc, dc, yts, conv, endofMonth)
end

""" 
fixing_date(idx::InterestRateIndex, d::Date) \n
It returns the fixing date from the value date (=d)
"""
fixing_date(idx::InterestRateIndex, d::Date) = advance(Dates.Day(-idx.fixingDays), idx.fixingCalendar, d)
""" 
maturity_date(idx::IborIndex, d::Date) \n
It returs the end of the period from the value date(=d)
"""
function maturity_date(idx::IborIndex, d::Date) 
    mat = advance(idx.tenor.period, idx.fixingCalendar, d)
    if idx.endOfMonth && is_endofmonth(d)
        return lastdayofmonth(mat)
    else
        return mat
    end
end
""" 
value_date(idx::IborIndex, d::Date) \n
returs the value date from the fixing date
"""
value_date(idx::IborIndex, d::Date) = advance(Dates.Day(idx.fixingDays), idx.fixingCalendar, d)

function fixing(idx::InterestRateIndex, ts::TermStructure, _fixing_date::Date, forcast_todays_fixing::Bool = true)
    today = settings.evaluation_date

    if _fixing_date > today || (_fixing_date == today && forcast_todays_fixing)
        return forecast_fixing(idx, ts, _fixing_date)
    end

    pastFix = get(idx.pastFixings, _fixing_date, -1.0)

    if pastFix ≈ -1.0
        return forcast_fixing(idx, ts, _fixing_date)
    else
        return pastFix
    end
    
end

function forcast_fixing(idx::InterestRateIndex, ts::TermStructure, _fixing_date::Date)
    d1 = value_date(idx, _fixing_date)
    d2 = maturity_date(idx, d1)
    t = year_fraction(idx.dc, d1, d2)
    return forecast_fixing(idx, ts, d1, d2, t)
end

function forcast_fixing(idx::InterestRateIndex, ts::TermStructure, d1::Date, d2::Date, t::Float64)
    disc1 = discount(ts, d1)
    disc2 = discount(ts, d2)
    return (disc1 / disc2 - 1.0) / t
end

is_valid_fixing_date(idx::InterestRateIndex, d::Date) = is_business_day(idx.fixingCalendar, d)

function add_fixing!(idx::InterestRateIndex, d::Date, fixingVal::Float64)
    idx.pastFixings[d] = fixingVal

    return idx
end

# Libor methods
function value_date(idx::LiborIndex, d::Date)
    new_d = advance(Dates.Day(idx.fixingDays), idx.fixingCalendar, d, idx.convention)
    return adjust(idx.jointCalendar, idx.convention, new_d)
end
  
function maturity_date(idx::LiborIndex, d::Date)
    mat = advance(idx.tenor.period, idx.fixingCalendar, d)
    if idx.endOfMonth && is_endofmonth(d)
        return lastdayofmonth(mat)
    else
        return mat
    end
end
  