struct OvernightIndex{TP<: TenorPeriod, CUR <: AbstractCurrency, B <: BusinessCalendar,
                        C <: BusinessDayConvention, DC <: DayCount, T <: TermStructure} <: InterestRateIndex
    familyName::String

    fixingPeriod::TP # basically swap fixing period, e.g., "3M", "6M", etc
                     # the nature of overnight index is taken care of since this type is separately defined.
    paymentPeiord::TP 
    
    fixingDays::Int  # -1,-2, etc: e.g., (fixing, value, value_end) = (d + fixingDays, d, d+"3M")
    currency::CUR
    fixingCalendar::B
    convention::C
    
    dc::DC
    yts::TermStructure
    pastFixings::Dict{Date, Float64}
    endOfMonth::Bool
end

function OvernightIndex(familyName::String, fixingPeriod::TP, paymentPeriod::TP, 
                        fixingDays::Int, currency::CUR, fixingCalendar::B, 
                        dc::DC, convention::C, ts::T = NullTermStructure(), pastFixings = Dict{Date, Float64}(),
                        eom::Bool = false) where {TP <: TenorPeriod, CUR <: AbstractCurrency, B <: BusinessCalendar, C <: BusinessDayConvention, DC <: DayCount, T <: TermStructure} 
    # BoB
    return OvernightIndex{TP, CUR, B, C, DC, T}(familyName, fixingPeriod, 
                                                paymentPeriod, fixingDays, currency, 
                                                fixingCalendar, convention,
                                                dc, ts, pastFixings, eom)
end

"""
first_fixing_date means like 3M, 6M
"""
function fixing(idx::OvernightIndex,  _fixing_date::Date, 
                ts::TermStructure = idx.yts,
                start_date::Date = _fixing_date, end_date::Date = _fixing_date,
                forcast_todays_fixing::Bool = true)
    # BoB        
    today = settings.evaluation_date
    if _fixing_date > today || (_fixing_date == today && forcast_todays_fixing)
        return forecast_fixing(idx, ts, _fixing_date)
    end

    fix = fixing_with_past(idx, _fixing_date, start_date, end_date)
    return fix
end

function fixing_with_past(idx::OvernightIndex, _fixing_date::Date, 
                            start_date::Date = _fixing_date, end_date::Date = _fixing_date)
    past_intervals = interval_value(idx, start_date, end_date)
    res = compound(idx, past_intervals, end_date)-1.0
    res /= year_fraction(idx.dc, start_date, end_date)
    return res
end

"""
This returns \n
[[fixing_date, start_date, adjust(start_date +Day(1)), value], ...]
"""
function interval_value(idx::OvernightIndex, start_date::Date, end_date::Date)
    fixingDays = idx.fixingDays
    cal = idx.fixingCalendar
    _past = idx.pastFixings
    _past = filter(d -> start_date <= advance(Day(-fixingDays), cal, d.first), _past)
    _past = filter(d -> advance(Day(1), cal, advance(Day(-fixingDays), cal, d.first)) <= end_date, _past) # Dict
    
    past = sort([[d.first, d.second] for d in _past], by= x->x[1])

    function interval(fixing::Date, fixing_days::Int, cal::BusinessCalendar)
        s = advance(Day(-fixing_days), cal, fixing)
        e = advance(Day(1), cal, s)
        return s, e
    end
    res = map(x->[x[1], interval(x[1], fixingDays, idx.fixingCalendar)..., x[2]], past)
    res[1][2] = minimum([res[1][2], start_date])
    return res
end

function _past_compound(idx::OvernightIndex, x::Vector{Vector{Any}})
    _dc = idx.dc
    function _daily_compound(dc::DayCount, s::Date, e::Date, r::Float64)
        return (1.0 + year_fraction(dc, s, e)*r)
    end
    return mapreduce(z-> _daily_compound(_dc, z[2:end]...), *, x)
end

function compound(idx::OvernightIndex, x::Vector{Vector{Any}}, end_date::Date)
    past_compound = _past_compound(idx, x)
    past_end = x[end][3]
    frac = year_fraction(idx.dc, past_end, end_date)
    r = forward_rate(idx.yts, idx.yts.referenceDate, end_date, idx.dc).rate
    return past_compound * (1.0+frac*r)
end

function earliest_intrerval(idx::OvernightIndex, d::Date, schedule::Schedule)
    payDays = idx.paymentDays
    paydate = Date(0)
    count = 1
    len = length(schedule)
    while d > paydate && count <= len
        count += 1
        paydate = adjust(idx.fixingCalendar, idx.paymentConvention, schedule[count] + Day(payDays))
    end
    return (schedule[count-1], schedule[count], paydate)
end

#=
function interval_value(idx::OvernightIndex, start_date::Date, end_date::Date)
    fixingDays = idx.fixingDays
    cal = idx.fixingCalendar
    _past = idx.pastFixings
    _past = filter(d -> start_date <= advance(Day(-fixingDays), cal, d.first), _past)
    _past = filter(d -> advance(Day(1), cal, advance(Day(-fixingDays), cal, d.first)) <= end_date, _past) # Dict
    
    past = sort([[d.first, d.second] for d in _past], by= x->x[1])

    function interval(fixing::Date, fixing_days::Int, cal::BusinessCalendar)
        s = advance(Day(-fixing_days), cal, fixing)
        e = advance(Day(1), cal, s)
        return s, e
    end
    res = map(x->[x[1], interval(x[1], fixingDays, cal)..., x[2]], past)
    res[1][2] = minimum([res[1][2], start_date])
    return res
end

function _past_compound(idx::OvernightIndex, x::Vector{Vector{Any}})
    _dc = idx.dc
    function _daily_compound(dc::DayCount, s::Date, e::Date, r::Float64)
        return (1.0 + year_fraction(dc, s, e)*r)
    end
    return mapreduce(z-> _daily_compound(_dc, z[2:end]...), *, x)
end

function compound(idx::OvernightIndex, x::Vector{Vector{Any}}, end_date::Date)
    past_compound = _past_compound(idx, x)
    past_end = x[end][3]
    frac = year_fraction(idx.dc, past_end, end_date)
    r = forward_rate(idx.yts, idx.yts.referenceDate, end_date, idx.dc)
    return past_compound * (1.0+frac*r.rate)
end
=#