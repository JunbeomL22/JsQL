abstract type Range end
abstract type Barrier end

struct LowerRange <: Range
    lower::Float64
end

struct UpperRange <: Range
    upper::Float64
end

struct BoundedRange <: Range
    lower::Float64
    upper::Float64
end

(r::LowerRange)(x::Float64) = r.lower <= x 
(r::UpperRange)(x::Float64) = x <= r.upper
(r::BoundedRange)(x::Float64) = r.lower <= x <= r.upper

struct LowerBarrier <: Barrier
    lower::Float64
end

struct UpperBarrier <: Barrier
    upper::Float64
end

struct BoundedBarrier <: Barrier
    lower::Float64
    upper::Float64
end

(b::UpperBarrier)(x::Vector{Float64})  = all(x .< b.upper)
(b::LowerBarrier)(x::Vector{Float64})  = all(b.lower .< x)
(b::BoundedBarrier)(x::Vector{Float64})= all(b.lower .< x .< b.upper)