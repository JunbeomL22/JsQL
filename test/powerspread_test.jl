using JsQL
using Random
using Dates
using BenchmarkTools

ref_date = Date(2021, 1, 2)
dates = [ref_date + Month(i) for i =0:2]
sigma = [0.1, 0.1, 0.1]

vol = TimeStepVolatility(ref_date, dates, sigma)
#plot(lin, test_local.(lin))

"""
This builds y(t) as a StepForwardInterpolation.
StepForwardInterpolation is chosen for both convenience and computational efficiency.
"""
function build_y(lambda::Float, times::Vector{Float}, sigma::Vector{Float}, maxTime::Float=20.0, timeStep::Int=20*252)
    times[1] ≈ 0.0 || error("The first element in times is not zero, location: build_y")
    length(sigma) != 1 || pushfirst!(times, times[1]) || pushfirst!(sigma, sigma[1])

    sigma_squared = sigma .^2.0
    rhs_point = typeof(sigma_squared)(undef, length(sigma_squared))
    rhs_point[1] = sigma_squared[1]
    rhs_point[2:end] = (sigma_squared[2:end] - sigma_squared[1:end-1]) .* exp.(2.0*lambda .* times[2:end]) ./(2.0*lambda)
    rhs_interp = JsQL.Math.StepForwardInterpolation(times, rhs_point)

    lhs_interp = JsQL.Math.StepForwardInterpolation(times, sigma_squared)

    y_times  = collect(range(0.0, maxTime, length=timeStep))

    _x = exp.((2.0*lambda) .* y_times) .* lhs_interp.(y_times) ./ (2.0*lambda)
    _z = rhs_interp.(y_times)
    _w = exp.(-(2.0*lambda) .* y_times)

    y_values = _w.*( _x - _z)

    y_interp = JsQL.Math.StepForwardInterpolation(y_times, y_values)
    return y_interp
end

@enter y = build_y(0.5, vol.times, vol.sigma)

#=
po = PowerSpreadPayoff(0.035, 0.0, 0.065, 15.0, Date(2021, 1, 4), Date(2021, 3, 1), [1.0, -1.0], [Ave(), Ave()])

cal= JsQL.Time.SouthKoreaSettlementCalendar()

start_date = Date(2021, 1, 4)
end_date = start_date + Year(1)
dtg = JsQL.Time.DateTimeGrid(start_date, end_date)
dt = Vector{Float64}(undef, length(dtg.times))
dt[2:end] = dtg.times[2:end] - dtg.times[1:end-1]
dt[1]=0.0
simnum=2
vals = randn(simnum, length(dtg.times)) .* sqrt.(dt)'
path = Path(dtg, vals)
=#