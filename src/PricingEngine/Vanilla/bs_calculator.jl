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
    d1 = ( log(x/(strike + compound_div) )  + log(div_disc/rate_disc) + 0.5*std_dev^2.0 ) / std_dev
    d2 = d1 - std_dev
    n_d1 = cdf(Normal(), d1)
    n_d2 = cdf(Normal(), d2)
    
    return BsCalculator(process, option, payoff, strike,
                        maturity, mat_time, compound_div, 
                        forward, forward_value,
                        rate_disc, div_disc, std_dev,
                        d1, d2, n_d1, n_d2, x0)
end

function initialize!(calc::BsCalculator)
    calc.matTime = year_fraction(calc.process.riskFreeRate.referenceDate, calc.maturity)
    calc.compoundDiv = compounded_accumulated_dividend(calc.process, 0.0, calc.matTime )

    calc.rateDiscount = discount(calc.process.riskFreeRate, calc.matTime)
    calc.divDiscount  = discount(calc.process.dividendYield, calc.matTime)

    calc.forward = forward_price(calc.process, calc.maturity)
    calc.forwardValue = (calc.forward  - calc.strike) * calc.rateDiscount

    calc.stdDev = calc.process.BlackConstantVol.volatility.value * sqrt(calc.matTime)
    
    calc.d1 = ( log(x/(calc.strike + calc.compoundDiv) )  + log(calc.divDiscount / calc.rateDiscount) + 0.5 * calc.stdDev^2.0 ) / calc.stdDev
    d2 = d1 - std_dev
    n_d1 = cdf(Normal(), d1)
    n_d2 = cdf(Normal(), d2)
end

function value(calc::BsCalculator, spot::Float64 = -Inf)
    if spot == -Inf
        call_price = calc.x0 * calc.n_d1 - calc.rateDiscount * (calc.strike + calc.compoundDiv) * calc.n_d2

        if calc.payoff.opt == Call()
            return call_price
        else
            return call_price - calc.forward_value
        end
    else
        _process = deepcopy(calc.process)
        _process.x0.value = spot
        _opt = deepcopy(calc.option)
        _calc= deep
    end
end

function delta(calc::BsCalculator)
    call_delta = calc.divDiscount * calc.n_d1
    if calc.payoff.opt == Call()
        return call_delta
    else
        return call_price - calc.divDiscount
    end
end

function gamma(calc::BsCalculator)
    ret = calc.divDiscount / (calc.x0 * calc.stdDev) * exp(-calc.d1^2.0 / 2.0) / sqrt(2.0 * π) 
end

"""
vega(calc::BsCalculator) \n
1\% vega
"""
function vega(calc::BsCalculator)
    ret = 0.01 * calc.x0 * calc.divDiscount * sqrt(calc.matTime / (2.0*π)) * exp(- calc.d1^2.0 / 2.0)
    return ret
end

function theta(calc::BsCalculator)
    
end
"""
rho(calc::BsCalculator) \n
1% rho \n
I ignore the rho from dividends, more precisely \n
d_r V(r, D(r)) = ∂_r V(r, D(r)) + ∂_D V(r, D(r)) ∂_r D(r) ≈ ∂_r V(r, D(r)) \n
"""
function rho(calc::BsCalculator)
    call_rho = 0.01 * (calc.strike + calc.compoundDiv)*calc.matTime * calc.rateDiscount * calc.n_d2
    put_rho  = -0.01 * (calc.strike + calc.compoundDiv)*calc.matTime * calc.rateDiscount * cdf(Normal(), -calc.d2)
    return calc.payoff.opt == Call() ? call_rho : put_rho
end
"""
div_rho(calc::BsCalculator) \n
1% dividend rho from the continuous dividend rate. The discrete part is not calculated.\n
"""
function div_rho(calc::BsCalculator)
    call_rho = - 0.01 * calc.matTime * calc.divDiscount * calc.x0 * calc.n_d1
    put_rho  = call_rho - 0.01 * calc.x0 * calc.matTime * calc.divDiscount / calc.rateDiscount
    return calc.payoff.opt == Call() ? call_rho : put_rho
end



