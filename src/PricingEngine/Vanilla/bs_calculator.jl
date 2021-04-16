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

    bsCalc = BsCalculator(process, option, option.payoff,
                            0.0, Date(1900, 1, 1), 0.0, 0.0, 0.0, 
                            0.0, 0.0, 0.0, 0.0, 0.0, 0.0, 0.0, 0.0, 0.0)
    initialize!(bsCalc)
    
    return bsCalc
end

function initialize!(calc::BsCalculator, process::AbstractBlackScholesProcess = calc.process, option::EuropeanOption = calc.option)
    calc.payoff   = option.payoff
    calc.strike   = option.payoff.strike 
    calc.maturity = option.exercise.dates[end]
    calc.matTime  = year_fraction(process.riskFreeRate.referenceDate, calc.maturity)
    calc.compoundDiv = compounded_accumulated_dividend(process, 0.0, calc.matTime)
    
    calc.rateDiscount = discount(process.riskFreeRate,  calc.matTime)
    calc.divDiscount  = discount(process.dividendYield, calc.matTime)

    calc.forward = forward_price(process, calc.matTime)
    calc.forwardValue = (calc.forward - calc.strike) * calc.rateDiscount

    calc.stdDev = process.BlackConstantVol.volatility.value*sqrt(calc.matTime)
    calc.x0 = process.x0.value
    #musiela formula below
    calc.d1 = ( log(calc.x0/(calc.strike + calc.compoundDiv) ) 
                    + log(calc.divDiscount/calc.rateDiscount) + 0.5*calc.stdDev^2.0 ) / calc.stdDev
    calc.d2 = calc.d1 - calc.stdDev
    calc.n_d1 = cdf(Normal(), calc.d1)
    calc.n_d2 = cdf(Normal(), calc.d2)
end

function value(calc::BsCalculator, spot::Float64 = -Inf)
    if spot == -Inf
        call_price = calc.x0 * calc.n_d1 - calc.rateDiscount * (calc.strike + calc.compoundDiv) * calc.n_d2

        if calc.payoff.opt == Call()
            return call_price
        else
            return call_price - calc.forwardValue
        end
    else
        init = calc.process.x0.value
        calc.process.x0.value = spot
        initialize!(calc)
        calc.process.x0.value = init
        return value(calc)
    end
end

function delta(calc::BsCalculator, spot::Float64 = -Inf)
    if spot == -Inf
        call_delta = calc.divDiscount * calc.n_d1
        if calc.payoff.opt == Call()
            return call_delta
        else
            return call_price - calc.divDiscount
        end
    else
        init = calc.process.x0.value
        calc.process.x0.value = spot
        initialize!(calc)
        calc.process.x0.value = init
        return delta(calc)
    end
end

function gamma(calc::BsCalculator, spot::Float64 = -Inf)
    if spot == -Inf
        ret = calc.divDiscount / (calc.x0 * calc.stdDev) * exp(-calc.d1^2.0 / 2.0) / sqrt(2.0 * π) 
    else
        init = calc.process.x0.value
        calc.process.x0.value = spot
        initialize!(calc)
        calc.process.x0.value = init
        return gamma(calc)
    end
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
    σ = calc.process.blackVolatility.volatility.value
    r = -log(calc.rateDiscount) / calc.matTime
    X = calc.strike + calc.compoundDiv
    T = calc.matTime
    r = forward_rate(calc.process.riskFreeRate,  calc.matTime, calc.matTime + 0.0001)
    q = forward_rate(calc.process.dividendYield, calc.matTime, calc.matTime + 0.0001)
    rate_disc = calc.rateDiscount
    div_disc = calc.divDiscount
    ret = -(calc.x0 * σ * calc.rateDiscount * exp(-0.5*calc.d1^2.0)) / (2.0*sqrt(calc.matTime * 2.0*π))
    if calc.payoff.opt == Call()
        return (ret - r*X*rate_disc*calc.nd2 + q*calc.x0 * div_disc*calc.nd1) / T
    else
        return ( ret + r*X*rate_disc*(1.0-calc.nd2) - q*calc.x0 * div_disc*(1.0-calc.nd1) ) / T
    end
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



