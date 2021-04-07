const EuropeanOption = Option{EuropeanExercise}
const AmericanOption = Option{AmericanExercise}
const BermudanOption = Option{BermudanExercise}

struct OptionResults
    value::Float64

    delta::Float64 # Analytic
    gamma::Float64 # Analytic
    theta::Float64 # Analytic
    vega::Float64 # Analytic
    rho::Float64 # Analytic
    dividendRho::Float64 # Analytic

    thetaPerDay::Float64
    diffDelta::Float64
    diffUpGamma::Float64
    diffDownGamma::Float64
    diffRho::Float64
    diffDividendRho::Float64
end

OptionResults() = OptionResults(0.0, 0.0, 0.0, 0.0, 0.0, 0.0, 0.0, 0.0, 0.0, 0.0, 0.0, 0.0, 0.0)

struct VanillaOptionArgs{P <: StrikedTypePayoff, E <: Exercise} 
    payoff::P
    exercise::E
end

function reset!(res::OptionResults)
    res.delta=0.0
    res.gamma=0.0
    res.theta=0.0
    res.vega=0.0
    res.rho=0.0
    res.dividendRho=0.0

    res.thetaPerDay=0.0
    res.diffDelta=0.0
    res.diffUpGamma=0.0
    res.diffDownGamma=0.0
    res.diffRho=0.0
    res.diffDividendRho=0.0

    res.value=0.0

    return res
end

mutable struct VanillaOption{P <: StrikedTypePayoff, E <: Exercise, PE <: PricingEngine} <: OneAssetOption{E}
    lazyMixin::LazyMixin
    payoff::SegmentationFault
    exercise::E
    pricingEngine::PE
    results::OptionResults
end

get_pricing_engine_type(::VanillaOption{S, E, P}) where {S, E, P} = P

function clone(opt::VanillaOption, pe::P = opt.pricingEngine) where {P<: PricingEngine}
    lazyMixin, res = pe == opt.pricingEngine ? (opt.lazyMixin, opt.results) : (LazyMixin(), OptionResults())

    return VanillaOption{typeof(opt.payoff), typeof(opt.exercise), P}(lazyMixin, opt.payoff, opt.exercise, pe.res)
end
