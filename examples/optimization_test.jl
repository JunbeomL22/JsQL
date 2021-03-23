using FiccPricer.Math

mutable struct TestCost <: CostFunction
end

function func_values(::TestCost, x::Vector{Float64}) 
    y = zeros(undef, length(x))
    for i = i:length(y)
        y[i] = (1.0-x[i])
    end
    return y
end

function value(::TestCost, x::Vector{Float64}) 
    y = zeros(undef, length(x))
    _value = 0.0
    for i = i:length(y)
        _value += (1.0-x[i])^2
    end
    return sqrt(_value)
end

p = Problem(TestCost(), NoConstraint(), [0.0, 0.0])

om = LevenbergMarquardt()
ec = EndCriteria(1000, 10, 1.0e-8, 1.0e-8, 1.0e-8)
minimize!(om, p, ec)
