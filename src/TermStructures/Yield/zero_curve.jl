using Dates
"""
Inputs are zero rates. Then interpolation is implemented on discount factors
"""
mutable struct ZeroCurve{DC <: DayCount, P<: Interpolation, B<: BusinessCalendar} <: InterpolatedCurve{P}
    settlementDays::Int # what is this?
    referenceDate::Date # where to use?
    dc::DC
    interp::P
    cal::B
    dates::Vector{Date}
    times::Vector{Float64}
    rates::Vector{Float64}
    discounts::Vector{Float64}
end

function ZeroCurve(dates::Vector{Date}, rates::Vector{Float64}, 
    dc::DC, interpolator::P) where {DC <: DayCount, P <: Interpolation}

    zc = ZeroCurve{DC, P, NullCalendar}(0, dates[1], dc, interpolator, 
                                        NullCalendar(), dates, zeros(length(dates)), 
                                        rates, zeros(length(dates)))
    initialize!(zc)

    return zc
end

function initialize!(zc::ZeroCurve)
    length(zc.times) != length(zc.discounts) && error("dates / data mismatch")
    zc.times[1] = 0.0
    @simd for i = 2:length(zc.dates)
        @inbounds zc.times[i] = year_fraction(zc.dc, zc.dates[1], zc.dates[i])
    end
    zc.discounts = exp.( - zc.times .* zc.rates)
    # initialize interpolator
    Math.initialize!(zc.interp, zc.times, zc.discounts)

    Math.update!(zc.interp)

    return zc
end

