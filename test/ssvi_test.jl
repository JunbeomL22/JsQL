using JsQL
using Dates
using Plots

now = today()
d1  = Date(2021, 5, 21)
t1 = (d1 - now).value / 365.0
d2  = Date(2021, 6, 18)
t2 = (d2 - now).value / 365.0
strikes = [0.8, 0.9, 0.95, 0.975, 1.0, 1.025, 1.05, 1.1, 1.2]
log_strikes = log.(strikes)
vol1 = [34.28, 25.0-4.0, 20.75, 18.47, 16.15, 14.27, 13.2, 13.36, 18.49]
# vol1 = [34.28-10.0, 20.75, 18.47, 16.15, 14.27, 13.2, 13.36]
vol2 = [32.55, 24.72, 21.02, 19.02, 17.02, 15.30, 14.12, 13.58, 16.53]

# --- totla variance --- #
tv1 = (vol1*0.01).^2.0 * t1
tv2 = (vol2*0.01).^2.0 * t2

# --- define cost function  --- #
ssvi_cost1 = SsviCost(strikes, vol1, t1, scale=0.01, isStrikeLog = false)
# --- define constraints  --- #
base_constraint = QuotientSsviBase()
butterfly_only = QuotientButterfly()
butterfly = JsQL.Math.JointConstraint(butterfly_only, base_constraint)
# --- define initial values --- #
initial_value = [-0.01, 0.01, 0.01, 0.01] # ρ, θ, η, γ
# --- define problem and optimization method--- #
p1 = JsQL.Math.Problem(ssvi_cost1, butterfly, copy(initial_value))
p1_noconstraint = JsQL.Math.Problem(ssvi_cost1, base_constraint, copy(initial_value))
#om = JsQL.Math.LevenbergMarquardt(1.0e-5, 1.0e-5, 1.0e-5, true)
om = JsQL.Math.Simplex(0.01)
ec = JsQL.Math.EndCriteria(10000, 10, 1.0e-8, 1.0e-8, 1.0e-8)
# --- minimize ---#
JsQL.Math.minimize!(om, p1, ec)
JsQL.Math.minimize!(om, p1_noconstraint, ec)
# -------  results  -------- #
params = p1.currentValue
params += [0.2, 0.0, 0.2, 0.0]
ssvi1 = Ssvi(p1.currentValue)
ssvi1_changed = Ssvi(p1.currentValue)
ssvi1_noconstraint = Ssvi(p1_noconstraint.currentValue)
fitted_vol1 = sqrt.( ssvi1.(log_strikes) / t1 )
fitted_vol1_noconstraint = sqrt.( ssvi1_noconstraint.(log_strikes) / t1 )
#JsQL.Math.test(butterfly, p1.currentValue)
p = plot(strikes, fitted_vol1, label = "fitted volatilities", seriestype = :line)
plot!(p, strikes, fitted_vol1_noconstraint, label = "no constraint", seriestype = :line)
plot!(p, strikes, 0.01*vol1, label = "volatility data", seriestype = :scatter)
#
# ----- the second problem ---- #
calender_only = SsviCalendar(log.(strikes), ssvi1.(log_strikes))
arbitrage_free = JsQL.Math.JointConstraint(calender_only, butterfly)

ssvi_cost2 = SsviCost(strikes, vol2, t2, scale=0.01, isStrikeLog = false)

p2 = JsQL.Math.Problem(ssvi_cost2, butterfly, copy(initial_value))

p2_noconstraint = JsQL.Math.Problem(ssvi_cost2, base_constraint, copy(initial_value))

JsQL.Math.minimize!(om, p2, ec)
JsQL.Math.minimize!(om, p2_noconstraint, ec)


ssvi2 = Ssvi(p2.currentValue)
ssvi2_noconstraint = Ssvi(p2_noconstraint.currentValue)
fitted_vol2 = sqrt.( ssvi2.(log_strikes) / t2 )
fitted_vol2_noconstraint = sqrt.( ssvi2_noconstraint.(log_strikes) / t2 )

p = plot(strikes, fitted_vol2, label = "fitted volatilities", seriestype = :line)
plot!(p, strikes, fitted_vol2_noconstraint, label = "no constraint", seriestype = :line)
plot!(p, strikes, 0.01*vol2, label = "volatility data", seriestype = :scatter)



