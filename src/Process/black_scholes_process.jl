struct GeneralBlackScholesType <: BlackScholesType end
struct BlackScholesMertonType <: BlackScholesType end
struct BlackScholesDiscreteDividendType <: BlackScholesType end

struct BlackScholes{Y1 <: YieldTermStructure, Y2 <: YieldTermStructure, 
                B <:BlackVolTermStructure, LC <: LocalVolTermStructure, 
                D <: AbstractDiscretization, BST <: BlackScholesType, 
                P<: Interpolation} <: AbstractBlackScholesProcess
    x0::Quote
    riskFreeRate::Y1
    dividendYield::Y2
    quantoCorr::QuantoCorrelation
    blackVolatility::B
    localVolatility::LC
    disc::D
   
    dividendScedule::Vector{Date}
    dividendTimes::Vector{Float64}
    dividendAmounts::Vector{Float64} # The values are like 30, 40, etc when x0.value is like 4000
    divInterp::P # stepwise interpolation of accumulated div amount

    blackScholesType::BST
    refPrice::Float64 # els reference price 
    initialValue::Float64 # x0 / refPrice | this will be used in simulation
end

function BlackScholes(x0::Quote, riskFreeRate::Y1, dividendYield::Y2, 
                        blackVolatility::BlackConstantVol, 
                        disc::D = EulerDiscretization(),
                        corr::Float64 = 0.0,
                        refPrice::Float64=1.0) where {Y1 <: YieldTermStructure, Y2 <: YieldTermStructure, 
                                                        D <: AbstractDiscretization}
    # BoB                            
    localVolatility = LocalConstantVol(blackVolatility.referenceDate, black_vol(blackVolatility, 0.0, x0.value), blackVolatility.dc)
    quanto = QuantoCorrelation(riskFreeRate.referenceDate, Quote(corr))
    BS = BlackScholes{Y1, Y2, BlackConstantVol, LocalConstantVol, D, GeneralBlackScholesType}
    return BS(x0, riskFreeRate, dividendYield, 
                quanto, 
                blackVolatility, localVolatility, disc, 
                Date[], Float64[], Float64[], StepwiseInterpolation(), 
                GeneralBlackScholesType(),
                refPrice,
                x0.value/refPrice)
end

function BsmProcess(x0::Quote, riskFreeRate::Y1, dividendYield::Y2,
                    blackVolatility::BlackConstantVol, 
                    disc::D = EulerDiscretization(),
                    corr::Float64 = 0.0, 
                    refPrice::Float64=1.0) where {Y1 <: YieldTermStructure, Y2 <: YieldTermStructure, D <: AbstractDiscretization}
    localVolatility = LocalConstantVol(blackVolatility.referenceDate, black_vol(blackVolatility, 0.0, x0.value), blackVolatility.dc)
    quanto = QuantoCorrelation(riskFreeRate.referenceDate, Quote(corr))
    return BlackScholes{Y1, Y2, BlackConstantVol, LocalConstantVol, D, BlackScholesMertonType}(
            x0, riskFreeRate, dividendYield, quanto, blackVolatility, localVolatility, disc, 
            BlackScholesMertonType(), refPrice, x0.value/refPrice)
end

function BsmDiscreteDiv(x0::Quote, 
                        riskFreeRate::Y, 
                        blackVolatility::BlackConstantVol, 
                        dividendSchdule::Vector{Date}, 
                        dividendAmounts::Vector{Float64}, 
                        disc::D = EulerDiscretization(),
                        refPrice::Float64=1.0) where {Y <: YieldTermStructure, D <: AbstractDiscretization}

    localVolatility = LocalConstantVol(blackVolatility.referenceDate, black_vol(blackVolatility, 0.0, x0.value), blackVolatility.dc)
    quanto = QuantoCorrelation(riskFreeRate.referenceDate, Quote(corr))
    refDate = blackVolatility.referenceDate
    dividendTimes = (dividendSchdule .-refDate) .|> x -> x.value / 365.0
    div_amounts = dividendAmounts .* (x0.value / refPrice)
    interp = StepwiseInterpolation(dividendTimes, accumulate(+, dividendAmounts))
    return BlackScholes{Y, NullYieldTermStructure, BlackConstantVol, LocalConstantVol, D, BlackScholesDiscreteDividendType}(
                        x0, 
                        riskFreeRate, 
                        NullYieldTermStructure(), 
                        quanto, 
                        blackVolatility, 
                        localVolatility, 
                        disc, 
                        dividendSchdule, 
                        dividendTimes, 
                        dividendAmounts,
                        interp, 
                        BlackScholesDiscreteDividendType(),
                        refPrice,
                        x0.value/refPrice)
end
function update!(process::BlackScholes)
    refDate = process.riskFreeRate.referenceDate
    if refDate == process.dividendScedule[1]
        process.initialValue -= process.dividendAmounts[1]
        process.x0.value -= process.dividendAmounts[1] * process.refPrice
    end
    div_dates = process.dividendScedule
    div_amounts = process.dividendAmounts
    div_dates_bit = refDate .< process.DividendSchedule
    process.dividendScedule = div_dates[div_Dates_bit]
    process.dividendAmounts = div_amounts[div_Dates_bit]
    process.dividendTimes = (process.dividendSchdule .-refDate) .|> x -> x.value / 365.0
    process.divInterp.x_vals = process.dividendTimes 
    process.divInterp.x_vals = accumulate(+, process.dividendAmounts)
end
"""
forward_price(::GeneralizedBalckScholesProcess, ::Float64) \n
Note that this is somehow an approximation. The reference is below: \n
https://quant.stackexchange.com/questions/16129/black-scholes-formula-with-deterministic-discrete-dividend-musiela-approach
"""
forward_price(process::BlackScholes, t::Float64) = forward_price(process, process.blackScholesType, t)

function forward_price(process::BlackScholes, date::Date)
    t = year_fraction(JsQL.Time.Act365(), process.riskFreeRate.referenceDate, date)
    return forward_price(process, process.blackScholesType, t)
end

function forward_price(process::BlackScholes, ::Union{GeneralBlackScholesType, BlackScholesMertonType}, t::Float64)
    riskFreeDiscount = discount(process.riskFreeRate, t)
    dividendDiscount = discount(process.dividendYield, t)
    forward = process.x0.value * dividendDiscount / riskFreeDiscount
    return forward
end

function forward_price(process::BlackScholes, ::BlackScholesDiscreteDividendType, t::Float64)
    riskFreeDiscount = discount(process.riskFreeRate, t)
    forward = dividend_deduction(process, t) / riskFreeDiscount
    return forward
end
"""
dividend_deduction(::BlackScholes, ::Float64) \n
This returns the value after discounted dividends are deducted
"""
function dividend_deduction(process::BlackScholes, t::Float64)
    #riskFreeDiscount = discount(process.riskFreeRate, t)
    time_masking = process.dividendTimes .<= t
    div_time = process.dividendTimes[time_masking]
    div_disc = map(z -> discount(process.riskFreeRate, z), div_time)
    amortized = sum(process.dividendAmounts[time_masking] .* div_disc)
    res = process.x0.value - amortized 
    return res
end
"""
accumulated_dividend(::BlackScholes, ::Float64, ::Float64) \n
This returns the accumulated dividend (undiscounted) between t1 and t2 
"""
function accumulated_dividend(process::BlackScholes, t1::Float64, t2::Float64)
    return process.divInterp(t2) - process.divInterp(t1)
end
"""
compunded_accumulated_dividend(::BlackScholes, ::Float64, ::Float64) \n
This returns the accumulated dividend (undiscounted) between t1 and t2 
"""
function compounded_accumulated_dividend(process::BlackScholes, t1::Float64, t2::Float64)
    riskFreeDiscount = discount(process.riskFreeRate, t2)
    time_masking = t1 .< process.dividendTimes .<= t2
    div_time = process.dividendTimes[time_masking]
    div_disc = map(z -> discount(process.riskFreeRate, z), div_time)
    ret = sum(process.dividendAmounts[time_masking] .* div_disc)
    ret /= riskFreeDiscount
    return res
end

drift(process::BlackScholes, t::Float64, x::Float64) = drift(process, process.blackScholesType, t, x)

function drift(process::BlackScholes, ::Union{GeneralBlackScholesType, BlackScholesMertonType}, t::Float64, x::Float64)
    t1 = t + 0.0001
    rate_forward = forward_rate(process.riskFreeRate, t, t1, ContinuousCompounding(), NoFrequency()).rate 
    div_forward = forward_rate(process.dividendYield, t, t1, ContinuousCompounding(), NoFrequency()).rate
    return x * ( rate_forward - div_forward ) 
end

function drift(process::BlackScholes, ::BlackScholesDiscreteDividendType, t::Float64, x::Float64)
    t1 = t + 0.0001
    rate_forward = forward_rate(process.riskFreeRate, t, t1, ContinuousCompounding(), NoFrequency()).rate 
    return x * rate_forward 
end

diffusion(process::BlackScholes, t::Float64, x::Float64) = diffusion(process, process.blackScholesType, t, x)

function diffusion(process::BlackScholes, ::Union{GeneralBlackScholesType, BlackScholesMertonType}, t::Float64, x::Float64) 
    return local_vol(process.localVolatility, t, x) * x
end

state_variable(p::AbstractBlackScholesProcess)=p.x0

get_time(p::AbstractBlackScholesProcess, d::Date)= year_fraction(p.riskFreeRate.dc, reference_date(p.riskFreeRate), d)

"""
t = w + dt
"""
expectation(process::BlackScholes, ::Float64, ::Float64, ::Float64) = error("not implemented")

apply(::BlackScholes, x0::Float64, dx::Float64) = x0 + dx

function evolve(process::BlackScholes, t::Float64, x::Float64, dt::Float64, dw::Float64)
    return evolove(process, process.blackScholesType, t, x, dt, dw)
end

function evolve(process::BlackScholes, ::Union{GeneralBlackScholesType, BlackScholesMertonType}, t::Float64, x::Float64, dt::Float64, dw::Float64)
    dividend = accumulated_dividend(process, t, t + dt)

    return  x + drift(process.disc, process, t, x, dt) + diffusion(process.disc, t, x, dt) * dw - dividend
    
end

