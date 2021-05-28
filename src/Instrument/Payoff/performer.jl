abstract type PerformanceType end
struct Worst <: PerformanceType end
struct Best <: PerformanceType end
struct Ave <: PerformanceType end
struct Diff <: PerformanceType end

function (::Ave)(x::Vector{Float64})
    len = size(x)[1]
    return sum(x) / len
end

(::Worst)(x::Vector{Float64}) = min(x...)

function (::Worst)(x::Matrix{Float64})
    col = size(x)[2]
    res = Vector{Float64}(undef, col)
    for i=1:col
        res[i] = min(x[:, i]...)
    end
    return res
end

(::Best)(x::Vector{Float64}) = max(x...)

function (::Best)(x::Matrix{Float64})
    col = size(x)[2]
    res = Vector{Float64}(undef, col)
    for i=1:col
        res[i] = max(x[:, i]...)
    end
    return res
end
