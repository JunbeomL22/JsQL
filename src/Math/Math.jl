module Math

abstract type FunctionType end

struct Derivative <: FunctionType end


# interpolation.jl
export Interpolation, LinearInterpolation, value, value_flat_outside, update!, locate, initialize!, derivative

include("Interpolation/interpolation.jl")
include("Interpolation/linear_interpolation.jl")
end