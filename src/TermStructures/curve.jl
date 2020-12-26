struct NullCurve <: Curve end

max_date(curve::InterpolatedCurve) = curve.dates[end]

discount(curve::Curve, t::Float64) = discount_impl(curve, t)

function discount_impl(curve::Curve, t::Float64)
    #calculate!(curve)
    if t ≤ curve.times[end]
        return 0.0 #Math.value(curve.interp, t)
    end
    return 0.0
end