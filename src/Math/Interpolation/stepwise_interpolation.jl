mutable struct StepwiseInterpolation <: Interpolation
    x_vals::Vector{Float64}
    y_vals::Vector{Float64}
end

StepwiseInterpolation() = StepwiseInterpolation(Float64[], Float64[])

function value(interp::StepwiseInterpolation, val::Float64)
    i = 0
    if val < interp.x_vals[1]
        i = 1
    else
        i = searchsortedlast(interp.x_vals, val)
    end
    return interp.y_vals[i]
end
