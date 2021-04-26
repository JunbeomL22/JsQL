struct OvernightIndex{TP<: TenorPeriod, CUR <: AbstractCurrency, B <: BusinessCalendar,
                C <: BusinessDayConvention, DC <: DayCount, T <: TermStructure} <: InterestRateIndex
    #
    familyName::String
    #
    fixingPeriod::TP
    paymentPeiord::TP 
    #
    fixingDays::Int # Normally Day(1)
    currency::CUR
    fixingCalendar::B
    convention::C
    #endOfMonth::Bool
    dc::DC
    yts::TermStructure
    pastFixings::Dict{Date, Float64}
end

function OvernightIndex(familyName::String, fixingPeriod::TP, paymentPeriod::TP, 
                        fixingDays::Int, currency::CUR, fixingCalendar::B, 
                        convention::C, ts::T = NullTermStructure(), pastFixings = Dict{Date, Float64}()
                        ) where {TP <: TenorPeriod, CUR <: AbstractCurrency, B <: BusinessCalendar, 
                                C <: BusinessDayConvention, DC <: DayCount, T <: TermStructure} 
    # BoB
    return OvernightIndex{TP, CUR, B, C, DC, T}(familyName, fixingPeriod, 
                                                paymentPeriod, fixingDays, currency, 
                                                fixingCalendar, convention,
                                                dc, ts, pastFixings)
end

function fixing(idx::InterestRateIndex,  _fixing_date::Date, 
                ts::TermStructure = idx.ts, forcast_todays_fixing::Bool = true)
    today = settings.evaluation_date

    if _fixing_date > today || (_fixing_date == today && forcast_todays_fixing)
        return forecast_fixing(idx, ts, _fixing_date)
    end

    pastFix = get_past_fixing(idx.pastFixings, _fixing_date, -1.0)

    if pastFix ≈ -1.0
        return forcast_fixing(idx, ts, _fixing_date)
    else
        return pastFix
    end
end

function get_past_fixing(idx::OvernightIndex, _fixing_start_date::Date, default_value::Float64 = -1.0)
    
end

function get_last_fixing(idx::OvernightIndex, _fixing_date::Date)
    d1 = value_date(idx, _fixing_date)
    d2 = maturity_date(idx, d1)
    fixing = advance(Dates.Day(-idx.fixingDays), idx.fixingCalendar, d2)
    return fixing
end

