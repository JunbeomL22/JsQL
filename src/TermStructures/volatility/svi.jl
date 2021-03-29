const RAWSVI_INITIAL_A     = 1.0e-2 # not recommended to use. Minimal total variance is recommended
const RAWSVI_INITIAL_B     = 0.1
const RAWSVI_INITIAL_RHO   = -0.5
const RAWSVI_INITIAL_M     = 0.1
const RAWSVI_INITIAL_SIGMA = 0.1

struct RawSviIntialValue
    init::Vector{Float64}
end 
RawSviIntialValue() = RawSviIntialValue([RAWSVI_INITIAL_A, RAWSVI_INITIAL_B, RAWSVI_INITIAL_RHO, RAWSVI_INITIAL_M, RAWSVI_INITIAL_SIGMA])

abstract type Svi end

struct RawSvi <: Svi 
    a::Float64
    b::Float64
    ρ::Float64
    m::Float64
    σ::Float64
end

function RawSvi(x::Vector{Float64})
    a=x[1]; b=x[2]; ρ=x[3]; m=x[4]; σ=x[5]
    return RawSvi(a, b, ρ, m, σ)
end

(s::RawSvi)(k::Float64) = s.a + s.b*( s.ρ*(k-s.m) + sqrt((k-s.m)^2.0 + s.σ^2.0) )

# ------------

struct RawSviBaseConstraint <: FiccPricer.Math.Constraint end

function FiccPricer.Math.test(::RawSviBaseConstraint, x::Vector{Float64})
    a=x[1]; b=x[2]; ρ=x[3]; m=x[4]; σ=x[5]

    if b < 0
        return false
    elseif abs(ρ) >= 1.0
        return false
    elseif σ <= 0.0
        return false
    elseif a + b*σ*sqrt(1.0-ρ^2.0) < 0.0
        return false
    end

    return true
end

# ----------------
struct RawSviButterFlyConstraint <: FiccPricer.Math.Constraint end

"""
Retrived from https://hal.archives-ouvertes.fr/hal-02517572/document
"""
function FiccPricer.Math.test(::RawSviButterFlyConstraint, x::Vector{Float64})
    a=x[1]; b=x[2]; ρ=x[3]
    m=x[4]; σ=x[5]
    
    n1 = a - m*b*(ρ+1.0)
    n2 = 4.0 -a + m*b*(ρ+1.0)
    d = b^2.0 * (ρ+1.0)^2.0

    if d - n1*n2 >= 0.0
        return false
    end
    #-----
    n1 = a - m*b*(ρ - 1.0)
    n2 = 4.0 - a + m*b*(ρ - 1.0)
    d = b^2.0 * (ρ - 1.0)^2.0

    if d - n1*n2 >= 0.0 
        return false
    end
    #------
    t3= 
    if ~( 0.0 < b^2.0 * (ρ+1.0)^2.0 < 4.0 )
        return false
    end
    #------
    t4= 
    if ~( 0.0 < b^2.0 * (ρ-1.0)^2.0 < 4.0 )
        return false
    end
    return true
end

struct CalendarConstraint <: FiccPricer.Math.Constraint 
    prevLogStrikes::Vector{Float64}
    prevTotalVariance::Vector{Float64}
end

function FiccPricer.Math.test(cal::CalendarConstraint, x::Vector{Float64})
    length(x) == 5 || error("svi parameter lenght is wrong")
    svi = RawSvi(x)
    currentTotalVariance = svi.(cal.prevLogStrikes)
    return all(cal.prevTotalVariance .< currentTotalVariance)
end

struct SviCost <: FiccPricer.Math.CostFunction
    logStrikes::Vector{Float64}
    totalVariances::Vector{Float64}
end

"""
If volatility is something like 24.23, use scale = 0.01
Likewise, if it is 0.02423, use scale = 1.0
"""
function SviCost(strikes::Vector{Float64}, volatilities::Vector{Float64},
    time::Float64; scale::Float64 = 0.01, isStrikeLog::Bool = false)
# BoB
    log_strikes = copy(strikes)
    if ~isStrikeLog
        log_strikes = log.(strikes)
    end
    volatilities = volatilities * scale
    total_variances = (volatilities .* volatilities) * time

    return SviCost(log_strikes, total_variances)
end

function value(sviCost::SviCost, x::Vector{Float64})
    logStrikes     = sviCost.logStrikes
    totalVariances = sviCost.totalVariances

    svi = RawSvi(x)
    diff = svi.(logStrikes) - totalVariances
    _value = sum(diff .^ 2.0)

    return _value
end