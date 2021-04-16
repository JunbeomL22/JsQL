struct AnalyticEuropeanEngine{P <: AbstractBlackScholesProcess} <: PricingEngine
    process::P
end

function _calculate!(pe::AnalyticEuropeanEngine, opt::EuropeanOption, spot::Float64 = pe.process.x0.value)
    payoff = opt.payoff
    variance = black_variance(pe.process.blackVolatility, opt.exercise.dates[end], payoff.strike)

    dividendDiscount=discount(pe.process.dividendYield, opt.exercise.dates[end]) # equal to 1 if the dividend is Null
    riskFreeDiscount=discount(pe.process.riskFreeRate, opt.exercise.dates[end])

    forward_price(pe.process, opt.exercise.dates[end])

    bs = BsCalculator(pe.process, opt)

    opt.results.value = value(bs, spot)
    opt.results.delta = delta(bs, spot)
    opt.results.gamma = gamma(bs, spot)

    opt.results.rho        = rho(bs)
    opt.result.dividendRho = div_rho(bs)
    opt.results.theta = theta(bs)
end