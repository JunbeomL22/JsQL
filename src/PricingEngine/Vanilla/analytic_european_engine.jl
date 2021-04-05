struct AnalyticEuropeanEngine{P <: AbstractBlackScholesProcess} <: PricingEngine
    process::P
end

function _calculate!(pe::AnalyticEuropeanEngine, opt::EuropeanOption)
    payoff = opt.payoff
    variance = black_variance(pe.process.blackVolatility, opt.exercise.dates[end], payoff.strike)
end