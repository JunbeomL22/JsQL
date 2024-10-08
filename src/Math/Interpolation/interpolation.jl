abstract type Interpolation end
abstract type Interpolation2D <: Interpolation end

abstract type DerivativeApprox end
abstract type BoundaryCondition end

function update!(interp::Interpolation, idx::Int, val::Float)
    interp.y_vals[idx] = val
    update!(interp, idx)

    return interp
end

function locate(interp::Interpolation, val::Float)
    if val < interp.x_vals[1]
        return 1
    elseif val >= interp.x_vals[end - 1]
        # return interp.x_vals[end] - interp.x_vals[1] - 2
        return length(interp.x_vals) - 1
    else
        # return findfirst(interp.x_vals .> val) - 1 # need to look at this
        return searchsortedlast(interp.x_vals, val)
    end
end

(p::Interpolation)(x::Float) = value(p, x)