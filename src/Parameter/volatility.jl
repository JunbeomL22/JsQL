
struct ConstantVolatility <: Volatility 
    sigma::Union{Float32, Float64}
end

local_vol(v::ConstantVolatility, t::Float, x::Float) = v.sigma
local_vol(v::ConstantVolatility) = v.sigma

struct TimeStepVolatility <: Volatility 
    refDate::Date
    dates::Vector{Date} #first element is refDate
    times::Vector{Float} #first element is refDate
    sigma::Vector{Float}
    interp::StepForwardInterpolation
end

function TimeStepVolatility(refDate::Date, dates::Vector{Date}, sigma::Vector{Float})
    length(dates) == length(sigma) || error("sigma and dates have different length, location: TimeStepVolatltiy")
    dates[1] == refDate || error("the first element in dates is not refDate, location: TimeStepVolatility")
    times = map(x-> year_fraction(refDate, x), dates)
    interp = StepForwardInterpolation(times, sigma)

    return TimeStepVolatility(refDate, dates, times, sigma, interp)
end

local_vol(v::TimeStepVolatility, t::Float, x::Float) = v.interp(t)