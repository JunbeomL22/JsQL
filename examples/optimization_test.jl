using FiccPricer

mutable struct TestCost <: FiccPricer.Math.CostFunction
end

function FiccPricer.func_values(::TestCost, x::Vector{Float64}) 
    y = zeros(Float64, length(x))
    for i = 1:length(y)
        y[i] = (x[i]-1.0)
    end
    return y
end


function FiccPricer.value(::TestCost, x::Vector{Float64}) 
    y = zeros(Float64, length(x))
    _value = 0.0
    for i = 1:length(y)
        _value += (x[i]-1.0)^2
    end
    return sqrt(_value)
end

p = FiccPricer.Math.Problem(TestCost(), FiccPricer.Math.NoConstraint(), [1.0, 1.0])

om = FiccPricer.Math.LevenbergMarquardt()
ec = FiccPricer.Math.EndCriteria(1000, 10, 1.0e-8, 1.0e-8, 1.0e-8)
FiccPricer.Math.minimize!(om, p, ec)

println(p.functionValue)
print(p.currentValue)

#=
function calibrate!(model::ShortRateModel, instruments::Vector{C}, method::OptimizationMethod, endCriteria::EndCriteria,
    constraint::Constraint = model.privateConstraint, weights::Vector{Float64} = ones(length(instruments)), 
    fixParams::BitArray{1} = BitArray(undef, 0)) where {C <: CalibrationHelper}

    w = length(weights) == 0 ? ones(length(instruments)) : weights
    prms = get_params(model)
    # println("model params: ", prms)
    all = falses(length(prms))
    proj = Projection(prms, length(fixParams) > 0 ? fixParams : all)
    calibFunc = CalibrationFunction(model, instruments, w, proj)
    pc = ProjectedConstraint(constraint, proj)
    prob = Problem(calibFunc, pc, project(proj, prms))

    # minimization
    minimize!(method, prob, endCriteria)
    res = prob.currentValue
    set_params!(model, include_params(proj, res))

    return model
end
=#