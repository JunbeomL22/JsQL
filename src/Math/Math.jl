module Math

abstract type FunctionType end

struct Derivative <: FunctionType end

export # interpolation.jl
Interpolation, LinearInterpolation, value, value_flat_outside, update!, 
locate, initialize!, derivative

export # grid.jl
bounded_log_grid, log_grid

export # svd.jl
svd

export lmdif!, Projection, CostFunction, Constraint, NoConstraint, 
PositiveConstraint, BoundaryConstraint, OptimizationMethod, Problem,
ProjectedConstraint, OptimizationMethod, LevenbergMarquardt, SimplexProblem, EndCriteria,
project, minimize!, include_params, FINITE_DIFFERENCES_EPSILON

# Constants
const EPS_VAL = eps()

export GeneralLinearLeastSquares


include("optimization/lmdif.jl")
include("optimization/optimization.jl")
include("optimization/problem.jl")
include("optimization/levenberg_marquardt.jl")

include("Interpolation/interpolation.jl")
include("Interpolation/linear_interpolation.jl")
include("grid.jl")
include("svd.jl")
include("general_linear_least_squares.jl")

end