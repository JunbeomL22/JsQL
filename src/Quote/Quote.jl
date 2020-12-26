mutable struct Quote
    value::Float64
    is_valid::Bool

    Quote(value::Float64, is_valid::Bool) = new(value, is_valid)
end