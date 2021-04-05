const EuropeanOption = Option{EuropeanExercise}
const AmericanOption = Option{AmericanExercise}
const BermudanOption = Option{BermudanExercise}

struct OptionResults
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

    value::Float64
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

mutable struct VanillaOption{P <: StrikedTypePayoff, E <: Exercise, PE <: PricingEngine}
end
