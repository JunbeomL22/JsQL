abstract type ImpliedVolatilitySurface <: ImpliedVolatility end   

struct FunctionalSurface <: ImpliedVolatilitySurface 
    times::Vector{Float64}
    totalVarianceFitter::Vector{Function}
end

function (fs::FunctionalSurface)(t::Float64, x::Float64)
    i, ratio = interospect_index_ratio(t, fs.times)
    if i == 1
        return fs.totalVarianceFitter[i](x)
    elseif i == length(fs.times)
        return fs.totalVarianceFitter[i](x)
    else
        return ratio[2] * fs.totalVarianceFitter[i-1](x) + ratio[1] * fs.totalVarianceFitter[i](x)
    end
end

function local_vol_impl(volSurface::FunctionalSurface, t::Float64, x::Float64)
    w(z) = volSurface(t, z)
    wt(s) = volSurface(s, x)
    first_df = CentralDifference(1)

    return sqrt(first_df(wt, t) / dupire_formula_denominator(w, x))
end

function dupire_formula_denominator(f::Function, y::Float64, bump::Float64 = 1.0e-4)
    first_diff = CentralDifference(1, bump)
    second_diff = CentralDifference(2, bump)
    w  = f(y)
    dw = first_diff(f, y)
    ddw= second_diff(f, y)
    ret = 1.0 - y/w * dw 
    ret += 0.25 *(-0.25 + 1.0/w + y^2.0/w^2.0) * dw^2.0
    ret += 0.5 * ddw
end

mutable struct LocalVol{DC <:DayCount, IV <: ImpliedVolatility} <:LocalVolTermStructure
    referenceDate::Date
    settlementDays::Int
    volatility::IV 
    dc::DC
end

LocalVol(refDate::Date, volatility::IV, dc::DayCount) where {IV <: ImpliedVolatility}=LocalVol(refDate, 0, volatility, dc)

local_vol_impl(volTS::LocalVol, t::Float64, x::Float64) = local_vol_impl(volTS.volatility, t, x)

struct CentralDifference 
    order::Int
    bump::Float64
end

