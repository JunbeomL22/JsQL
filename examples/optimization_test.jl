using JsQL

mutable struct TestCost <: JsQL.Math.CostFunction
end

function JsQL.value(::TestCost, x::Vector{Float64}) 
    _value = 0.0
    for i = 1:length(x)
        _value += (x[i]+2.0)^2
    end
    return _value
end

mutable struct LinearTest <: JsQL.Math.CostFunction
    variables::Vector{Float64}
    observations::Vector{Float64}
end

function JsQL.value(lt::LinearTest, x::Vector{Float64}) 
    var = lt.variables
    y = lt.observations
    _value = 0.0
    for i = 1:length(y)
        _value += (x[1] + x[2]var[i] - y[i])^2
    end
    return _value
end
x = rand(1000); y = rand(1000)
vx = map(z->[z], x)
lt = LinearTest(x, y)
constraint = JsQL.Math.BoundaryConstraint(1.0, 1000.0)
p = JsQL.Math.Problem(lt, JsQL.Math.NoConstraint(), [3.0, 3.0])
pBoundary = JsQL.Math.Problem(lt, constraint, [3.0, 3.0])

om = JsQL.Math.LevenbergMarquardt()
#om = JsQL.Math.Simplex(10.0)
ec = JsQL.Math.EndCriteria(1000, 10, 1.0e-8, 1.0e-8, 1.0e-8)
JsQL.Math.minimize!(om, p, ec)
JsQL.Math.minimize!(om, pBoundary, ec)

#JsQL.Math.test(JsQL.Math.BoundaryConstraint(1.0, 5.0), pBoundary.currentValue)
######################

v = Function[]
JsQL.path_basis_system!(JsQL.Monomial(), v, 1, 1)
lsq = JsQL.Math.GeneralLinearLeastSquares(vx, y, v)
println("@ ---------- results ------------- @")
println("solution by $(typeof(om)):  ", p.currentValue)
println("bounded soultion by $(typeof(om)):  ", pBoundary.currentValue)
println("solution by lls: ", lsq.a)

println("@ ------------ error ------------- @")
println("original error by $(typeof(om)):  ", sum((p.currentValue[1] .+ p.currentValue[2]*x -y).^2.0))
println("error by lls: ", sum(lsq.residuals.^2))
println("bounded solution error by $(typeof(om)):  ", sum((pBoundary.currentValue[1] .+ pBoundary.currentValue[2]*x -y).^2.0))
println("@ ------- number of trials ------- @")
println("\nfunction evaluation of original: ", p.functionEvaluation)
println("function evaluation of bounded: ", pBoundary.functionEvaluation)
println("@ ------- constraint test -------- @")
println("does constraint work?: ", JsQL.Math.test(constraint, pBoundary.currentValue))
