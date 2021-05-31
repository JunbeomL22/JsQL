"""
OneFactorGsrProcess describes: \n
x(t) = r(t) - f(0, t) \n
dx(t) = (y(t) - λ(t)̇ x(t))dt - σ_r(t) dW(t), x(0)=0 \n
y(t) = ∫_0^t  exp(-2∫_u^t λ(s)ds) σ_r(u)^2 du \n
For now, we assume that λ is a constant \n
See Proposition 10.1.7. [p. 416] Interest Rate Modeling II, Piterbarg 
"""
struct OneFactorGsrProcess{Y <: YieldTermStructure, P1 <: Interpolation, 
                            P2 <: Interpolation, V <: Volatility} <: StochasticProcess1D
    x0::Float # == 0
    refDate::Date
    dtg::JsQL.Time.DateTimeGrid
    riskFreeRate::Y
    lambda::Float
    volatitliy::V
    y::P2
end

function OneFactorGsrProcess(dtg::JsQL.Time.DateTimeGrid, riskFreeRate::Y,
                            lambda::Float, volatility::TimeStepVolatility) where {Y <: YieldTermStructure}
    refDate = dtg.refDate

    y = build_y(lambda, volatility.times, volatility.sigma, dtg)

    return OneFactorGsrProcess(0.0, refDate, dtg, riskFreeRate, lambda, volatility, y)
end

"""
This builds y(t) as a StepForwardInterpolation.
StepForwardInterpolation is chosen for both convenience and computational efficiency.
"""
function build_y(lambda::Float, times::Vector{Float}, sigma::Vector{Float}, dtg::JsQL.Time.DateTimeGrid)
    times[1] ≈ 0.0 || error("The first element in times is not zero, location: build_y")
    length(sigma) != 1 || pushfirst!(times, times[1]) || pushfirst!(sigma, sigma[1])

    sigma_squared = sigma .^2.0
    rhs_point = typeof(sigma_squared)(undef, length(sigma_squared))
    rhs_point[1] = sigma_squared[1]
    rhs_point[2:end] = (sigma_squared[2:end] - sigma_squared[1:end-1]) .* exp.(2.0*lambda .* times[2:end]) 
    rhs_point = accumulate(+, rhs_point)
    rhs_interp = JsQL.Math.StepForwardInterpolation(times, rhs_point)

    ss_interp = JsQL.Math.StepForwardInterpolation(times, sigma_squared)

    y_times  = dtg.times

    _x = exp.((2.0*lambda) .* y_times) .* ss_interp.(y_times) 
    _z = rhs_interp.(y_times)
    _w = exp.(-(2.0*lambda) .* y_times) ./ (2.0*lambda)

    y_values = _w.*( _x - _z)

    y_interp = JsQL.Math.StepForwardInterpolation(y_times, y_values)
    return y_interp
end

function G(gsr::OneFactorGsrProcess, t1::Float, t2::Float)
    ld = gsr.lambda
    return (1.0 - exp(-ld*(t2-t1))) / ld
end

function bond(gsr::OneFactorGsrProcess, x::Float, t1::Float, t2::Float)
    yts = gsr.riskFreeRate
    market_bond = discount(yts, t2) / discount(yts, t1)
    g = G(gsr, t1, t2)
    y = gsr.y(t1)
    res = market_bond * exp(-x*g - 0.5*y*g^2.0)
    return res
end

get_init(gsr::OneFactorGsrProcess) = gsr.x0
drift(gsr::OneFactorGsrProcess, t::Float, x::Float) = gsr.y(t) - gsr.lambda * x

diffusion(gsr::OneFactorGsrProcess, t::Float, x::Float) = gsr.volatitliy.interp(t) 

function evolve(gsr::OneFactorGsrProcess, t::Float, x::Float, dt::Float, dw::Float)
    return x + drift(gsr, t, x)*dt + diccusion(gsr, t, x) * dw
end

