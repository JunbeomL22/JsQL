abstract type ImpliedVolatilitySurface <: ImpliedVolatility end   

struct FunctionalSurface <: ImpliedVolatilitySurface 
    times::Vector{Float64}
    totalVarianceFitter::Vector{Function}
end

function local_vol_impl(volSurface::FunctionalSurface, t::Float64, x::Float64)
    i, ratio = interospect_index_ratio(t, volSurface.times)
 -------------
 ------------
end
local_vol_impl(volSurface::FunctionalSurface, t::Float64, x::Float64) = volTS.volatility.value