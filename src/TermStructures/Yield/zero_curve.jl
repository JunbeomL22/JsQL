using Dates

mutable struct ZeroCurve{DC <: DayCount, P<: Interpolation, B<: BusinessCalendar} <: InterpolatedCurve{P}
    settlementDays::Int # what is this?
    referenceDate::Date # where to use?
    dc::DC
    interp::P
    cal::B
    dates::Vector{Date}
    times::Vector{Float64}
    data::Vector{Float64}
end

function ZeroCurve(dates::Vector{Date}, discounts::Vector{Float64}, 
    dc::DC, interpolator::P) where {DC <: DayCount, P <: Interpolation}

    zc = ZeroCurve{DC, P, NullCalendar}(0, dates[1], dc, interpolator, 
                                        NullCalendar(), dates, zeros(length(dates)), discounts)
    initialize!(zc)

    return zc
end

function ZeroCurve(times::Vector{Float64}, discounts::Vector{Float64}, 
    dc::DC, interpolator::P) where {DC <: DayCount, P <: Interpolation}

    zc = ZeroCurve{DC, P, NullCalendar}
    d = JsQL.Times.advance(Day(-1),  SouthKoreaKrxCalendar(), today())
    (0, d, dc, interpolator, NullCalendar(), Vector{Date}(undef, length(times)), times, discounts)
    initialize!(zc)

    return zc
end

function initialize!(zc::ZeroCurve)
    length(zc.times) != length(zc.data) && error("dates / data mismatch")
    zc.times[1] = 0.0
    @simd for i = 2:length(zc.dates)
        @inbounds zc.times[i] = year_fraction(zc.dc, zc.dates[1], zc.dates[i])
    end

    # initialize interpolator
    Math.initialize!(zc.interp, zc.times, zc.data)

    Math.update!(zc.interp)

    return zc
end

#=
function discount_impl(zc::ZeroCurve, t::Float64)
    if t ≤ zc.times[end]
      return Math.value(zc.interp, t)
    end
  -------------------------------------
    # flat fwd extrapolation
    tMax = zc.times[end]
    dMax = zc.data[end]
    instFwdMax = Math.derivative(zc.interp, tMax) / dMax
    return dMax * exp(-instFwdMax * (t - tMax))
  end
  =#