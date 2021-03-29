struct SviJw <: Svi 
    v::Float64
    ψ::Float64
    p::Float64
    c::Float64
    vt::Float64
    t::Float64
end

function (s::SviJw)(k::Float64)
    w = s.v*s.t
    b = 0.5*sqrt(w)*(s.c+s.p)
    ρ = 1.0 - s.p*sqrt(w)/b
    β = ρ - 2.0*s.ψ*sqrt(w)/b
    α = sign(β) * sqrt(1.0/(β^2.0) - 1.0)

    numer = (s.v - s.vt)*s.t 
    denom =  b*(-ρ + sign(α)*sqrt(1.0 + α^2.0) - α*sqrt(1.0-ρ^2.0)) 
    m = numer/denom

    σ = α*m
    a = s.vt*s.t - b*σ*sqrt(1.0-ρ^2.0)

    ret = ρ*(k - m) + sqrt((k - m)^2.0 + σ^2.0)
    ret = b*ret
    ret = a + ret
    return ret  
end 

struct ProjectedSviJw <: Svi 
    a::Float64
    b::Float64
    ρ::Float64
    m::Float64
    σ::Float64
end

function ProjectedSviJw(x::Vector{Float64})
    b=x[1]; m=x[2]; σ=x[3]

    ρ = -m/sqrt(m^2.0 + σ^2.0)
    a = 0.0

    x = -b*σ*sqrt(1.0 - ρ^2.0)
    y = b*(1.0-ρ^2.0)*(-ρ*m + sqrt(m^2.0+σ^2.0))
    if ρ ≈ 0.0
        ρ -= 0.001
    end
    a = (x + y) / (ρ^2.0)

    return ProjectedSviJw(a, b, ρ, m, σ)
end

(s::ProjectedSviJw)(k::Float64) = s.a + s.b*( s.ρ*(k-s.m) + sqrt((k-s.m)^2.0 + s.σ^2.0) )

struct ProjectedSviJwCost <: JsQL.Math.CostFunction
    logStrikes::Vector{Float64}
    totalVariances::Vector{Float64}
end

function ProjectedSviJwCost(strikes::Vector{Float64}, volatilities::Vector{Float64},
    time::Float64; scale::Float64 = 0.01, isStrikeLog::Bool = false)
# BoB
    log_strikes = copy(strikes)
    if ~isStrikeLog
        log_strikes = log.(strikes)
    end
    volatilities = volatilities * scale
    total_variances = (volatilities .* volatilities) * time

    return ProjectedSviJwCost(log_strikes, total_variances)
end

function value(sviCost::ProjectedSviJwCost, x::Vector{Float64}) # b, m, σ
    logStrikes     = sviCost.logStrikes
    totalVariances = sviCost.totalVariances

    svi = ProjectedSviJw(x)
    diff = svi.(logStrikes) - totalVariances
    _value = sum(diff .^ 2.0)

    return _value
end
struct ProjectedSviJwBaseConstraint <: JsQL.Math.Constraint end

function JsQL.Math.test(::ProjectedSviJwBaseConstraint, x::Vector{Float64})
    b=x[1]; m=x[2]; σ=x[3]
    if b < 0
        return false
    elseif σ <= 0.0
        return false
    end
    ρ = -m/sqrt(m^2.0 + σ^2.0)
    if abs(ρ) >= 1.0
        return false
    end
    return true
end

struct ProjectedSviJwButterFlyConstraint <: JsQL.Math.Constraint end

function JsQL.Math.test(::ProjectedSviJwButterFlyConstraint, x::Vector{Float64})
    b=x[1]; m=x[2]; σ=x[3]
    ρ = -m/sqrt(m^2.0 + σ^2.0)
    x = -b * σ * sqrt(1.0 - ρ^2.0)
    y = b*(1.0-ρ^2.0)*(-ρ*m + sqrt(m^2.0+σ^2.0))
    a = (x + y) / (ρ^2.0)

    w = (a + b*(-ρ*m + sqrt(m^2.0 + σ^2.0)))
    #w = v*t
    p = b*(1.0 - ρ)/sqrt(w)
    c = b*(1.0 + ρ)/sqrt(w)
    e = 1.0e-5
    rt1 = sqrt(w) * max(p+e, c+e)
    rt2 = (p+c+e) * max(p+e, c+e)
    if max(rt1, rt2) >= 2.0
        return false
    end
    return true
end

struct ProjCalendarConstraint <: JsQL.Math.Constraint 
    prevLogStrikes::Vector{Float64}
    prevTotalVariance::Vector{Float64}
end

function JsQL.Math.test(cal::ProjCalendarConstraint, x::Vector{Float64})
    length(x) == 5 || error("svi parameter lenght is wrong")
    svi = ProjectedSviJw(x)
    currentTotalVariance = svi.(cal.prevLogStrikes)
    return all(cal.prevTotalVariance .< currentTotalVariance)
end
