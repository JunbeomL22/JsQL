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
        _value += (x[1] + x[2]var[i] - y[i])^2
    end
    return _value
end
x = rand(10); y = rand(10)
vx = map(z->[z], x)
lt = LinearTest(x, y)
p = FiccPricer.Math.Problem(lt, FiccPricer.Math.NoConstraint(), [0.0, 0.0])

om = FiccPricer.Math.LevenbergMarquardt()
ec = FiccPricer.Math.EndCriteria(1000, 10, 1.0e-8, 1.0e-8, 1.0e-8)
FiccPricer.Math.minimize!(om, p, ec)

println(p.functionValue)
println(p.currentValue)
######################

v = Function[]
FiccPricer.path_basis_system!(FiccPricer.Monomial(), v, 1, 1)
lsq = FiccPricer.Math.GeneralLinearLeastSquares(vx, y, v)
println(lsq.a)
println(sum(lsq.residuals.^2))