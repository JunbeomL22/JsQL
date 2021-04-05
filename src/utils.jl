"""
interospect_index_ratio(x::Float64, v::Vector{Float64}) \n
If x = 4 and v = [1,3,6,7], this returns 3, (1/3, 2/3) \n
I assume the default starting point is 0, i.e., 
If x = 1 and v = [2,3,4], this returns 1, (0.5, 0.5)
"""
function interospect_index_ratio(x::T1, v::Vector{T2}) where {T1 <: Number, T2 <: Number}
    i = findfirst(λ-> λ>x , v)
    if i == 1
        return 1, (x/v[1], 1.0 - x/v[1])
    else
        st = v[i-1]
        ed = v[i]
        len = v[i] - v[i-1]
        diff = x - v[i-1]
        return i, (diff/len, 1.0-diff/len)
    end
end