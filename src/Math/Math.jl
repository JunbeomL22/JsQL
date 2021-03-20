module Math

abstract type FunctionType end

struct Derivative <: FunctionType end

export # interpolation.jl
Interpolation, LinearInterpolation, value, value_flat_outside, update!, locate, initialize!, derivative

export # grid.jl
bounded_log_grid, log_grid

export # svd.jl
svd

include("Interpolation/interpolation.jl")
include("Interpolation/linear_interpolation.jl")
include("grid.jl")
include("svd.jl")

end