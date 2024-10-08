mutable struct LinearInterpolation <: Interpolation
    x_vals::Vector{Float64}
    y_vals::Vector{Float64}
    s::Vector{Float64} # roughly, derivative 
    extrapolate::Bool
end

LinearInterpolation() = LinearInterpolation(Float64[], Float64[], Float64[], false)

function LinearInterpolation(x::Vector{Float64}, y::Vector{Float64}, extra::Bool = false) 
    interp = LinearInterpolation()
    interp.extrapolate = extra
    initialize!(interp, x, y)
    update!(interp)
    return interp
end

function initialize!(interp::LinearInterpolation, x_vals::Vector{Float64}, y_vals::Vector{Float64})
    interp.x_vals = x_vals
    interp.y_vals = y_vals
    interp.s = zeros(length(y_vals))
  
    return interp
end

# Linear Interpolation update
function update!(interp::LinearInterpolation, idx::Int)
    @simd for i = 2:idx
        @inbounds dx = interp.x_vals[i] - interp.x_vals[i - 1]
        @inbounds interp.s[i - 1] = (interp.y_vals[i] - interp.y_vals[i - 1]) / dx
    end
  
    return interp
end
  
update!(interp::LinearInterpolation) = update!(interp, length(interp.y_vals))
  
function value(interp::LinearInterpolation, val::Float64)
    i = locate(interp, val)
    if (val > interp.x_vals[end] && interp.extrapolate) || val <= interp.x_vals[end]
        return interp.y_vals[i] + (val - interp.x_vals[i]) * interp.s[i]
    else
        return interp.y_vals[end]
    end
end

function value_flat_outside(interp::LinearInterpolation, val::Float64)
    if val ≤ interp.x_vals[1]
        
        return interp.y_vals[1]
    elseif val ≥ interp.x_vals[end]
        return interp.y_vals[end]
    else
        i = locate(interp, val)
        return interp.y_vals[i] + (val - interp.x_vals[i]) * interp.s[i]
    end
end

function derivative(interp::LinearInterpolation, val::Float64)
    i = locate(interp, val)
    return interp.s[i]
end