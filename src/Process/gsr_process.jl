"""
OneFactorGsrProcess describes: \n

x(t) = r(t) - f(0, t) \n
dx(t) = (y(t) - λ(t)̇ x(t))dt - σ_r(t) dW(t), x(0)=0 \n
y(t) = ∫_0^t  exp(-2∫_u^t λ(s)ds) σ_r(u)^2 \du
For now, we assume that λ is a constant
See Proposition 10.1.7. [p. 416] Interest Rate Modeling II, Piterbarg ,
"""

struct OneFactorGsrProcess{Y <: YieldTermStructure, P1 <: Interpolation, P2 <: Interpolation} <: StochasticProcess1D
    refDate::Date
    riskFreeRate::Y
    lambda::Float
    sigmaStep::Vector{Float}
    sigmaData::Vector{Float}
    sigma::P1
    y::P2
end
#=
function make_y(lambda::Float, sigmaStep::Vector{Float}, sigmaData::Vector{Float})
    
end


function OneFactorGsrProcess(lambda::Float, sigmaStep::Vector{Float}, sigmaData::Vector{Float})

end
=#