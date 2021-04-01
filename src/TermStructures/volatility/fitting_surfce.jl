using JsQL
using Dates
"""
SSVI fitting \n
strikes is assumed not be log
"""
function fitting_surface(strikes::Vector{Float64}, times::Vector{Float64}, 
                        volData::Vector{Vector{Float64}}, 
                        removePoints::Int = 0)
    m = length(strikes)
    n = length(times)
    ssviVector = Vector{Ssvi}(undef, n) # thie will be returned

    @simd for i = 1:n
        @inbounds ssviVector[i] = fitting_slice(times[i], strikes)
    end

end

function fitting_surface(strikes::Vector{Float64}, dates::Vector{Date}, refDate::Date, 
                        volData::Vector{Vector{Float64}}, 
                        removePoints::Int = 0)
    # BoB
    diff = (dates .+ refDate)
    times = [x.value /365.0 for x in a]
    return fitting_surface(strikes, times, volData, removePoints)
end

"""
return ssvi. This checks only butterfly
"""
function fitting_slice(t::Float64, strikes::Vector{Float64}, volatility::Vector{Float64}, 
                        om::OptimizationMethod = JsQL.Math.Simplex(0.01), 
                        ec::EndCriteria = JsQL.Math.EndCriteria(10000, 10, 1.0e-8, 1.0e-8, 1.0e-8))
    length(strikes) == length(volatility) || error("length of strikes and vol data must be equal.")
    
    log_strikes = log.(strikes)
    tv = (volatility*0.01).^2.0 * t
    # --- define cost function  --- #
    ssvi_cost = SsviCost(strikes, volatility, t, scale=0.01, isStrikeLog = false)
    # --- define constraints  --- #
    base_constraint = QuotientSsviBase()
    butterfly_only = QuotientButterfly()
    butterfly = JsQL.Math.JointConstraint(butterfly_only, base_constraint)
    
    problem = JsQL.Math.Problem(ssvi_cost, butterfly, copy(initial_value))
    # --- minimize ---#
    JsQL.Math.minimize!(om, problem, ec)

    JsQL.Math.test(butterfly, problem.currentValue) || error("butterfly constraint is broken. took at time = $(t) and first vol = $(volatility[1])")

    return Ssvi(problem.currentValue)
end

"""
This returns vector of Ssvi, in which only butterfly and base constraints are checked.
"""
function fitting_surface(strikes::Vector{Float64}, times::Vector{Float64}, volData::Vector{Vector{Float64}})
    
    n = length(times)
    ssviVector = Vector{Ssvi}(undef, n) # thie will be returned

    @simd for i = 1:n
        @inbounds ssviVector[i] = fitting_slice(times[i], strikes, volData[i])
    end

    return ssviVector
end

function test_calenar(ssvis::Vector{Ssvi}, 
                    testing_logstriks::Vecto{Float64} = [-1.0, -0.5, -0.1, 0.0, 0.1, 0.5, 1.0])
    n = length(ssvis)
    @simd @inbounds for i =1:(n-1)
        calendar = SsviCalendar(testing_logstriks, ssvis[i].(testing_logstriks))
        if ~JsQL.Math.test(calendar, params(ssvis[i]))
            return false
        end
    end
    return true
end