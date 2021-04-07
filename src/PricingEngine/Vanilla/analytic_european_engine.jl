struct AnalyticEuropeanEngine{P <: AbstractBlackScholesProcess} <: PricingEngine
    process::P
end

function _calculate!(pe::AnalyticEuropeanEngine, opt::EuropeanOption)
    payoff = opt.payoff
    variance = black_variance(pe.process.blackVolatility, opt.exercise.dates[end], payoff.strike)

    dividendDiscount=discount(pe.process.dividendYield, opt.exercise.dates[end]) # equal to 1 if the dividend is Null
    riskFreeDiscount=discount(pe.process.riskFreeRate, opt.exercise.dates[end])

    spot = state_variable(pe.process).value
    forwardPrice = spot * dividendDiscount / riskFreeDiscount
end