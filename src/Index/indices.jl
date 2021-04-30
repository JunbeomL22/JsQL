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

# If it is 6M libor paied in quaterly basis, (fixing, payment) = (6M, 3M)
# The case that fixingPeriod < paymentPeriod:
# Libor => (1+r*tau) ; OIS => (1+r*tau) * ...* (1+r*tau)

# fixing Days refer to calc_start_date, e.g., in Libor case it is -2 days
# i.e., value_date + fixingDays = fixing_date
# i.e., end_date + paymentDays = maturity_date
struct IborIndex{TP<: TenorPeriod, CUR <: AbstractCurrency, B <: BusinessCalendar,
                    C <: BusinessDayConvention, DC <: DayCount, T <: TermStructure} <: InterestRateIndex
    #
    familyName::String
    #
    fixingPeriod::TP
    paymentPeiord::TP 
    #
    fixingDays::Int # Normally Day(2)
    currency::CUR
    fixingCalendar::B
    convention::C
    endOfMonth::Bool
    dc::DC
    yts::TermStructure
    pastFixings::Dict{Date, Float64}
end

function IborIndex(familyName::String, fixingPeriod::TP, paymentPeriod::TP, fixingDays::Int, currency::CUR, 
                    fixingCalendar::B, convention::C, endOfMonth::Bool, dc::DC, 
                    ts::T = NullTermStructure(), pastFixings = Dict{Date, Float64}()
                    ) where {TP <: TenorPeriod, CUR <: AbstractCurrency, 
                            B <: BusinessCalendar, C <: BusinessDayConvention, 
                            DC <: DayCount, T <: TermStructure} 
    # equal to 
    return IborIndex{TP, CUR, B, C, DC, T}(familyName, fixingPeriod, paymentPeriod, fixingDays, currency, 
                                            fixingCalendar, convention, endOfMonth, dc, ts, pastFixings)
end
"""
For Libor, \n
1) EOM and Modified Following applies \n
2) except EUR & GBP value date = two london business day + fixing date \n
3) except GBP, ACT/360 applies \n
"""
mutable struct LiborIndex{TP<: TenorPeriod, B <: BusinessCalendar,
                    C <: BusinessDayConvention, DC <: DayCount, T <: TermStructure} <: InterestRateIndex
    familyName::String
    fixingPeriod::TP
    paymentPeriod::TP
    fixingDays::Int
    currency::Currency
    fixingCalendar::B
    jointCalendar::JointCalendar
    dc::DC
    yts::TermStructure
    convention::C
    endOfMonth::Bool
    pastFixings::Dict{Date, Float64}
end

function LiborIndex(familyName::String, fixingPeriod::TP, paymentPeriod::TP, fixingDays::Int, 
                    currency::Currency, fixingCalendar::B, jointCalendar::JointCalendar,  
                    dc::DC, ts::T = NullTermStructure(), 
                    convention::C = ModifiedFollowing(), endOfMonth::Bool = true, 
                    pastFixings = Dict{Date, Float64}()
                    ) where {TP <: TenorPeriod, B <: BusinessCalendar, C <: BusinessDayConvention, 
                            DC <: DayCount, T <: TermStructure}
    # equal to 
    return LiborIndex{TP, B, C, DC, T}(familyName, fixingPeriod, paymentPeriod, fixingDays, currency, 
                                        fixingCalendar, jointCalendar, dc, ts, convention, endOfMonth, pastFixings)
end

function LiborIndex(familyName::String, fixingPeriod::TP, paymentPeriod::TP, fixingDays::Int, currency::Currency, 
                    fixingCalendar::B, dc::DC, yts::T, pastFixings::Dict{Date, Float64} = Dict{Date, Float64}()
                    ) where {TP <: TenorPeriod, B <: BusinessCalendar, 
                            DC <: DayCount, T <: TermStructure}
    # beginning of the body
    endofMonth = libor_eom(paymentPeriod.period)
    conv = libor_conv(paymentPeriod.period)
    jc = JointCalendar(JsQL.Time.UKLSECalendar(), fixingCalendar)

    return LiborIndex{TP, BusinessCalendar, BusinessDayConvention, DC, T}(familyName, fixingPeriod, paymentPeriod, fixingDays, currency, 
                                                                        fixingCalendar, jc, dc, yts, conv, endofMonth, pastFixings)
end

function usd_libor_index(fixingPeriod::TenorPeriod, paymentPeriod::TenorPeriod, yts::YieldTermStructure, pastFixings::Dict{Date, Float64} = Dict{Date, Float64}())
    return LiborIndex("USDLibor", fixingPeriod, paymentPeriod, -2, USDCurrency(), 
                        JsQL.Time.USSettlementCalendar(), JsQL.Time.Act360(), yts, pastFixings)
end
  
# fixing -> value -> maturity#
""" 
fixing_date(idx::InterestRateIndex, d::Date) \n
It returns the fixing date from the value date (=d)
"""
fixing_date(idx::InterestRateIndex, d::Date) = advance(Dates.Day(idx.fixingDays), idx.fixingCalendar, d)
""" 
maturity_date(idx::IborIndex, d::Date) \n
It returs the end (fixing) of the period from the value date(=d)
"""
function maturity_date(idx::InterestRateIndex, d::Date) 
    mat = advance(idx.fixingPeriod.period, idx.fixingCalendar, d)
    if idx.endOfMonth && is_endofmonth(d)
        return lastdayofmonth(mat)
    else
        return mat
    end
end
""" 
maturity_date(idx::IborIndex, d::Date) \n
It returs the end (fixing) of the period from the value date(=d)
"""
function payment_date(idx::InterestRateIndex, d::Date) 
    mat = advance(idx.paymentPeriod.period, idx.fixingCalendar, d)
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
value_date(idx::InterestRateIndex, d::Date) = advance(Dates.Day(-idx.fixingDays), idx.fixingCalendar, d)

function fixing_amount(idx::InterestRateIndex, _fixing_date::Date, forcast_todays_fixing::Bool = true)
    rate = fixing(idx, _fixing_date, idx.yts, forcast_todays_fixing)
    pay  = payment_date(idx, d)
    d1   = value_date(idx, _fixing_date)
    d2   = maturity_date(idx, d1)
    frac = year_fraction(idx.dc, d1, d2)
    return rate * frac
end

function fixing(idx::InterestRateIndex,  _fixing_date::Date, 
                ts::TermStructure = idx.yts, forcast_todays_fixing::Bool = true,
                start_date::Date = _fixing_date, end_date::Date = _fixing_date)
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
    new_d = advance(Dates.Day(-idx.fixingDays), idx.fixingCalendar, d, idx.convention)
    return adjust(idx.jointCalendar, idx.convention, new_d)
end
  
function maturity_date(idx::LiborIndex, d::Date)
    mat = advance(idx.fixingPeriod, idx.fixingCalendar, d)
    if idx.endOfMonth && is_endofmonth(d)
        return lastdayofmonth(mat)
    else
        return mat
    end
end
  
euribor_conv(::Union{Dates.Day, Dates.Week}) = JsQL.Time.Following()
euribor_conv(::Union{Dates.Month, Dates.Year}) = JsQL.Time.ModifiedFollowing()

euribor_eom(::Union{Dates.Day, Dates.Week}) = false
euribor_eom(::Union{Dates.Month, Dates.Year}) = true

libor_conv(::Union{Dates.Day, Dates.Week}) = JsQL.Time.Following()
libor_conv(::Union{Dates.Month, Dates.Year}) = JsQL.Time.ModifiedFollowing()

libor_eom(::Union{Dates.Day, Dates.Week}) = false
libor_eom(::Union{Dates.Month, Dates.Year}) = true

