mutable struct NodeData
    exerciseValue::Float64
    cumulatedCashFlow::Float64
    values::Vector{Float64}
    controlValue::Float64
    isValid::Bool
end

NodeData() = NodeData(0.0, 0.0, Vector{Float64}(), 0.0, false)