using Distributions

mutable struct BsCalculator{S <: StrikedTypePayoff, P <: AbstractBlackScholesProcess}
    process::P
    option::EuropeanOption
    payoff::S
    strike::Float64
    maturity::Date
    matTime::Float64
    compoundDiv::Float64
    forward::Float64
    forwardValue::Float64
    rateDiscount::Float64
    divDiscount::Float64
    stdDev::Float64
    d1::Float64
    d2::Float64
    n_d1::Float64
    n_d2::Float64
    x0::Float64
end

"""
I take Musiela-Rutkowski formula. \n
Reference for the variation of discrete dividend: \n
https://quant.stackexchange.com/questions/16129/black-scholes-formula-with-deterministic-discrete-dividend-musiela-approach
"""
function BsCalculator(process::P, option::EuropeanOption) where {P <: AbstractBlackScholesProcess}
    payoff = option.payoff
    maturity = option.exercise.dates[end]
    mat_time = year_fraction(process.riskFreeRate.referenceDate, maturity)
    compound_div = compounded_accumulated_dividend(process, 0.0, mat_time)
    strike = option.payoff.strike 

    rate_disc = discount(process.riskFreeRate, mat_time)
    div_disc = discount(process.dividendYield, mat_time)

    forward = forward_price(process, maturity)
    forward_value = (forward  - strike) * rate_disc

    std_dev = process.BlackConstantVol.volatility.value*sqrt(mat_time)
    x0 = process.x0.value
    #musiela formula below
    d1 = ( log(x/(strike + compound_div) )  - log(rate_disc) + 0.5*std_dev^2.0 ) / std_dev
    d2 = d1 - std_dev
    n_d1 = cdf(Normal(), d1)
    n_d2 = cdf(Normal(), d2)
    
    return BsCalculator(process, option, payoff, strike,
                        maturity, mat_time, compound_div, 
                        forward, forward_value,
                        rate_disc, div_disc, std_dev,
                        d1, d2, n_d1, n_d2, x0)
end

function reset!(calc::BsCalculator)
    calc.matTime = year_fraction(calc.process.riskFreeRate.referenceDate, calc.maturity)
    calc.compoundDiv = compounded_accumulated_dividend(calc.process, 0.0, calc.matTime )

    calc.rateDiscount = discount(calc.process.riskFreeRate, calc.matTime)
    calc.divDiscount  = discount(calc.process.dividendYield, calc.matTime)

    calc.forward = forward_price(calc.process, calc.maturity)
    calc.forwardValue = (calc.forward  - calc.strike) * calc.rateDiscount

    calc.stdDev = calc.process.BlackConstantVol.volatility.value * sqrt(calc.matTime)
    
    calc.d1 = ( log(x/(calc.strike + calc.compoundDiv) )  - log(calc.rateDiscount) + 0.5 * calc.stdDev^2.0 ) / calc.stdDev
    d2 = d1 - std_dev
    n_d1 = cdf(Normal(), d1)
    n_d2 = cdf(Normal(), d2)
end
function value(calc::BsCalculator)
    ret = calc.x * calc.n_d1 - calc.rateDiscount * (calc.strike + calc.compoundDiv) * calc.n_d2
    if calc.payoff.opt == Call()
        return ret
    else
        return ret - calc.forward_value
    end
end

function delta(calc::BsCalculator, ϵ::Float64 = 0.01)
    calculator = deepcopy(calc)
    calculator.x0 += ϵ
    pos_val = value(calculator)
    calculator.x0 -= ϵ
    neg_val = vlaue(calculator)

    return (pos_val - neg_val) / (2.0* ϵ)
end

function vega(calc::BsCalculator, ϵ::Float64 = 0.01)
    calculator = deepcopy(calc)
    calculator.x0 += ϵ
    pos_val = value(calculator)
    calculator.x0 -= ϵ
    neg_val = vlaue(calculator)

    return (pos_val - neg_val) / (2.0* ϵ)
end

function gamma(calc::BsCalculator, ϵ::Float64 = 0.01)
    
end

function theta(calc::BsCalculator, ϵ::Float64 = 1.0/250.)
    
end

function rho(calc::BsCalculator, ϵ::Float64 = 0.0001)
    
end

function div_rho(calc::BsCalculator, ϵ::Float64 = 0.0001)
    
end



