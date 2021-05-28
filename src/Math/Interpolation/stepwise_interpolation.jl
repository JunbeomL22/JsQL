mutable struct StepForwardInterpolation <: Interpolation
    x_vals::Vector{Float}
    y_vals::Vector{Float}
end

StepForwardInterpolation() = StepForwardInterpolation(Float64[], Float64[])

function value(interp::StepForwardInterpolation, val::Float)
    i = 0
    if val < interp.x_vals[1]
        i = 1
    else
        i = searchsortedlast(interp.x_vals, val)
    end
    return interp.y_vals[i]
end
