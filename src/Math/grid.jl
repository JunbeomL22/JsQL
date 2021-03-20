function bounded_log_grid(xMin::Float64, xMax::Float64, steps::Int, scale::Float64 = 1.0)
    result = zeros(steps + 1)
    gridLogSpacing = (log(xMax) - log(xMin)) / steps
    edx = exp(gridLogSpacing)
    result[1] = xMin
    @simd for j = 2:steps+1
        @inbounds result[j] = result[j-1] * edx
    end
  
    return result
end
  
function log_grid(left::Float64, right::Float64, center::Float64, leftStep::Int, rightStep::Int)
    leftGrid  = bounded_log_grid(left, center, leftStep)
    dt = diff(leftGrid)
    reverse!(dt) 
    
    leftGrid = zeros(leftStep)
    leftGrid[end] = center - dt[end]
    for i = leftStep-1:-1:1
        leftGrid[i] = leftGrid[i+1] - dt[i]
    end
    rightGrid = bounded_log_grid(right, center, rightStep)    

    v=(leftGrid, rightGrid[1:end])

    return vcat(v...)
end
