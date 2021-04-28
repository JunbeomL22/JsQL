using Dates
import Base.getindex, Base.length
"""
The nearest future date of 20th of Mar, Jun, Sep, direction \n
Necessary for CDS payment schedule
"""
function next_twentieth(d::Date)
    res = Date(year(d), month(d), 20)
    if res < d
        res += Month(1)
    end
    
    m = month(res)
    if m % 3 !=0
        skip_ =3 - m%3
        res += skip_ * Month(1)
    end

    return res
end

abstract type DateGenerationRule end
struct DateGenerationBackwards <: DateGenerationRule end
struct DateGenerationForwards <: DateGenerationRule end
struct DateGenerationTwentieth <: DateGenerationRule end

struct Schedule{B <: BusinessDayConvention, D <:DateGenerationRule, C <:BusinessCalendar}
    # BOB (the beginning of the body. will be used this later too)
    effectiveDate::Date # start date
    terminationDate::Date
    tenor::TenorPeriod
    convention::B # used in date generation
    rule::D
    endOfMonth::Bool
    dates::Vector{Date}
    cal::C
end

function Schedule(effectiveDate::Date, terminationDate::Date,
                            tenor::TenorPeriod, convention::B,
                            rule::D, endOfMonth::Bool, dates::Vector{Date}, 
                            cal::C = TargetCalendar()) where
                            {B <: BusinessDayConvention, D <:DateGenerationRule, C <:BusinessCalendar}
    # BOB 
    if !isempty(dates)
        dates[end] = adjust(cal, termDateConvention, dates[end])
    end
    return Schedule(effectiveDate, terminationDate, tenor, convention, 
                    rule, endOfMonth, dates, cal)
end

"""
constructor of forward DateGenerationBackward
"""
function Schedule(effectiveDate::Date, terminationDate::Date, tenor::TenorPeriod, 
                convention::B, rule::DateGenerationForwards, 
                endOfMonth::Bool=false, cal::C = SouthKoreaSettlementCalendar()) where 
                {B <: BusinessDayConvention, C <: BusinessCalendar}
    # BOB
    dates = Vector{Date}()
    dt = effectiveDate
    push!(dates, adjust(cal, convention, dt))
    dt += tenor.period
    while dt < terminationDate
        push!(dates, adjust(cal, convention, dt))
        dt += tenor.period
    end

    if dates[end] != terminationDate
       push!(dates, terminationDate) 
    end
    return Schedule{B, DateGenerationForwards, C}(effectiveDate, terminationDate, 
                                                    tenor, convention, rule, endOfMonth, dates, cal)
end

function Schedule(effectiveDate::Date, terminationDate::Date,
                tenor::TenorPeriod, convention::B, 
                rule::DateGenerationBackwards, endOfMonth::Bool=false,
                cal::C = SouthKoreaSettlementCalendar()) where {B <: BusinessDayConvention, C <: BusinessCalendar}
    size = get_size(tenor.period, effectiveDate, terminationDate) # get_size is defined later
    dates = Vector{Date}(undef, size)
    dates[1] = effectiveDate
    dates[end] = terminationDate
    period = 1
    @simd for i = size-1:-1:2
        @inbounds dates[i] = adjust(cal, convention, terminationDate - period * tenor.period)
        period +=1
    end
    return Schedule{B, DateGenerationBackwards, C}(effectiveDate, terminationDate, tenor, 
                                                        convention, rule, endOfMonth, dates, cal)
end

function Schedule(effectiveDate::Date, terminationDate::Date, tenor::TenorPeriod,
                convention::B, rule::DateGenerationTwentieth,
                endOfMonth::Bool, cal::C = SouthKoreaSettlementCalendar()) where 
                {B <: BusinessDayConvention, C <: BusinessCalendar}
    dates = Vector{Date}()
    dt = effectiveDate
    push!(dates, adjust(cal, convention, dt))
    seed = effectiveDate

    # next 20th
    next20th = next_twentieth(effectiveDate)

    if next20th != effectiveDate
        push!(dates, next20th)
        seed = next20th
    end

    seed += tenor.period
    while seed < terminationDate
        push!(dates, adjust(cal, convention, seed))
        seed += tenor.period
    end

    if dates[end] != adjust(cal, convention, terminationDate)
        push!(dates, next_twentieth(terminationDate))
    else
        push!(dates, terminationDate)
    end

    return Schedule{B, DateGenerationTwentieth, C}(effectiveDate, terminationDate, 
                                                tenor, convention, rule, 
                                                endOfMonth, dates, cal)
end

"""
get_size(p::Dates.Month, st::Date, ed::Date)
ed = Date(2021, 5, 1); st = Date(2021, 1, 1)
get_size(Month(3), st, ed) => 2
"""
function get_size(p::Dates.Month, st::Date, ed::Date)
    return Int( 
            ceil( 
                ceil( Dates.value(ed-st) / 30 ) / Dates.value(p)
                ))
end

"""
Really feel this is redundant \n
Anyhow, to give an example \n
get_size(Year(2), Date(2019, 1, 1), Date(2021, 6, 30)) => 2
"""
function get_size(p::Dates.Year, ed::Date, td::Date)
    if monthday(ed) == monthday(td)
        return Int( 
                ceil( 
                    round( Dates.value(td - ed) / 365 ) / Dates.value(p)
                    ))
    else
        return Int( ceil(
                        ceil( Dates.value(td - ed) / 365 ) / Dates.value(p)
                        ))
    end
end

getindex(s::Schedule, i::Int) = s.dates[i]
length(s::Schedule) = length(s.dates)
