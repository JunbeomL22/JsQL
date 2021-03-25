using FiccPricer

mutable struct TestCost <: FiccPricer.Math.CostFunction
end

function FiccPricer.value(::TestCost, x::Vector{Float64}) 
    _value = 0.0
    for i = 1:length(x)
        _value += (x[i]+2.0)^2
    end
    return _value
end

mutable struct LinearTest <: FiccPricer.Math.CostFunction
    variables::Vector{Float64}
    observations::Vector{Float64}
end

function FiccPricer.value(lt::LinearTest, x::Vector{Float64}) 
    var = lt.variables
    y = lt.observations
    _value = 0.0
    for i = 1:length(y)
        _value += (x[1]var[i]+x[2] - y[i])^2
    end
    return _value
end

lt = LinearTest([0.0, 1.0, -1.0], [0.0, 1.0, -1.0])
p = FiccPricer.Math.Problem(lt, FiccPricer.Math.NoConstraint(), [200.0, 1.0])

om = FiccPricer.Math.LevenbergMarquardt()
ec = FiccPricer.Math.EndCriteria(1000, 10, 1.0e-8, 1.0e-8, 1.0e-8)
FiccPricer.Math.minimize!(om, p, ec)

println(p.functionValue)
print(p.currentValue)
######################

FiccPricer.get_type(FiccPricer.Monomial())
v = MonomialFunction[]
FiccPricer.path_basis_system!(FiccPricer.Monomial(), v, 1, 1)
lsq = FiccPricer.Math.GeneralLinearLeastSquares([[0.0], [1.0], [-1.0]], [0.0, 1.0, -1.0], v)
