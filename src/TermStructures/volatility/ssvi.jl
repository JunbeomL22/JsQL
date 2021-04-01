abstract type SsviPhi <: Function end
# Jim Gatheral path 17, eq. (4.5)
struct QuotientPhi <: SsviPhi
    η::Float64
    γ::Float64
end

function QuotientPhi(x::Vector{Float64})
    η, γ = x
    # η > 0.0 + SVI_BUMP || error("η in ϕ is negative")
    # SVI_BUMP <= γ <= 1.0-SVI_BUMP  || error("γ in ϕ is out of the bound")
    return QuotientPhi(η, γ)
end

(q::QuotientPhi)(θ::Float64) = q.η / ( θ^q.γ * (1.0+θ)^(1.0-q.γ) )

struct Ssvi{SP <: SsviPhi}
    ρ::Float64
    θ::Float64
    ϕ::SP
end
params(s::Ssvi) = [s.ρ, s.θ, s.ϕ.η, s.ϕ.γ]
Ssvi(x::Vector{Float64}) = Ssvi(x[1:2]..., QuotientPhi(x[3:4]))
Ssvi(x::Vector{Float64}, ϕ::Phi) where {Phi <: SsviPhi} = Ssvi(x..., ϕ)

function (ss::Ssvi)(k::Float64) 
    ρ = ss.ρ
    θ = ss.θ
    ϕ = ss.ϕ
    return 0.5*θ * (   1.0 + ρ*ϕ(θ)*k + sqrt( (ϕ(θ)*k + ρ)^2.0 + (1.0-ρ^2.0) )   )
end

struct QuotientSsviBase <: JsQL.Math.Constraint end

function JsQL.Math.test(::QuotientSsviBase, x::Vector{Float64})
    ρ, θ, η, γ = x

    if ~(abs(ρ) <= 1.0-SVI_BUMP)
        return false
    elseif ~(θ >= SVI_BUMP)
        return false
    elseif ~(η >= SVI_BUMP)
        return false
    elseif ~( SVI_BUMP <= γ <= 1.0-SVI_BUMP)
        return false
    end
    return true
end

struct QuotientButterfly <: JsQL.Math.Constraint end

function JsQL.Math.test(::QuotientButterfly, x::Vector{Float64})
    ρ, θ, η, γ = x
    
    if ~( (η + SVI_BUMP) * (1.0 + abs(ρ + SVI_BUMP)) <= 2.0  )
        return false
    end
    return true
end
struct SsviCalendar <: JsQL.Math.Constraint 
    prevLogStrikes::Vector{Float64}
    prevTotalVariance::Vector{Float64}
end

function JsQL.Math.test(cal::SsviCalendar, x::Vector{Float64})
    ssvi = Ssvi(x)
    currentTotalVariance = ssvi.(cal.prevLogStrikes)
    return all(cal.prevTotalVariance .< currentTotalVariance)
end

struct SsviCost <: JsQL.Math.CostFunction
    logStrikes::Vector{Float64}
    totalVariances::Vector{Float64}
end


function SsviCost(strikes::Vector{Float64}, volatilities::Vector{Float64},
    time::Float64; scale::Float64 = 0.01, isStrikeLog::Bool = false)
# BoB
    log_strikes = copy(strikes)
    if ~isStrikeLog
        log_strikes = log.(strikes)
    end
    volatilities = volatilities * scale
    total_variances = (volatilities .* volatilities) * time

    return SsviCost(log_strikes, total_variances)
end

function value(ssviCost::SsviCost, x::Vector{Float64})
    logStrikes     = ssviCost.logStrikes
    totalVariances = ssviCost.totalVariances

    ssvi = Ssvi(x)
    diff = ssvi.(logStrikes) - totalVariances
    _value = sum(diff .^ 2.0)

    return _value
end

