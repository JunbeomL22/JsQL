using FiccPricer

mutable struct TestCost <: FiccPricer.Math.CostFunction
end

function FiccPricer.func_values(::TestCost, x::Vector{Float64}) 
    y = zeros(Float64, length(x))
    for i = 1:length(y)
        y[i] = (1.0-x[i])
    end
    return y
end

function FiccPricer.value(::TestCost, x::Vector{Float64}) 
    y = zeros(Float64, length(x))
    _value = 0.0
    for i = 1:length(y)
        _value += (1.0-x[i])^2
    end
    return sqrt(_value)
end

p = FiccPricer.Math.Problem(TestCost(), FiccPricer.Math.NoConstraint(), [0.0, 0.0])

om = FiccPricer.Math.LevenbergMarquardt()
ec = FiccPricer.Math.EndCriteria(1000, 10, 1.0e-8, 1.0e-8, 1.0e-8)
FiccPricer.Math.minimize!(om, p, ec)
