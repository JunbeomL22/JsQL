"""
interospect_index_ratio(x::Float64, v::Vector{Float64}) \n
If x = 4 and v = [1,3,6,7], this returns 3, (1/3, 2/3) \n
If x = 1 and v = [2,3,4], this returns 1, (0.0, 1.0)
"""
function interospect_index_ratio(x::T1, v::Vector{T2}) where {T1 <: Number, T2 <: Number}
    issorted(v) || error("the vector in instrospection util is not sorted.")
    i = findfirst(λ-> λ>x , v)
    if i == 1
        return 1, (0.0, 1.0)
    elseif i == nothing
        return length(v), (1.0, 0.0)
    else
        st = v[i-1]
        ed = v[i]
        len = v[i] - v[i-1]
        diff = x - v[i-1]
        return i, (diff/len, 1.0-diff/len)
    end
end

struct CentralDifference 
    order::Int
    bump::Float64
end

CentralDifference(order::Int) = CentralDifference(order, 1.0e-4)

function (c::CentralDifference)(f::Function, x::Float64)
    ret = 0.0
    Δ = c.bump
    if c.order == 1
        ret = ( f(x+Δ) - f(x-Δ) ) / (2.0*Δ)
    elseif c.order == 2
        ret = ( f(x+Δ) + f(x-Δ) - 2.0*f(x) ) / (Δ^2.0)
    else 
        error("higher order must be implemented")
    end 
    return ret
end