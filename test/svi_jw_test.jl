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
vol1 = [34.28, 25.0, 20.75, 18.47, 16.15, 14.27, 13.2, 13.36, 18.49]
vol2 = [32.55, 24.72, 21.02, 19.02, 17.02, 15.30, 14.12, 13.58, 16.53]

# --- totla variance --- #
total_variance1 = (vol1*0.01).^2.0 * t1
total_variance1 = (vol2*0.01).^2.0 * t2

# --- define cost function  --- #
svi_cost1 = SviCost(strikes, vol1, t1, scale=0.01, isStrikeLog = false)
svi_cost2 = SviCost(strikes, vol2, t2, scale=0.01, isStrikeLog = false)

proj_svi_cost1 = ProjectedSviJwCost(strikes, vol1, t1, scale=0.01, isStrikeLog = false)
proj_svi_cost2 = ProjectedSviJwCost(strikes, vol2, t2, scale=0.01, isStrikeLog = false)

# --- define constraints  --- #
butterfly_only = RawSviButterFlyConstraint()
base_constraint = RawSviBaseConstraint()
butterfly = JsQL.Math.JointConstraint(butterfly_only, base_constraint)



proj_butterfly_only = ProjectedSviJwButterFlyConstraint()
proj_base_constraint = ProjectedSviJwBaseConstraint()
proj_butterfly = JsQL.Math.JointConstraint(proj_butterfly_only, proj_base_constraint)


#om = JsQL.Math.LevenbergMarquardt()#(1.0e-5, 1.0e-5, 1.0e-5, true)
om = JsQL.Math.Simplex(0.01)
ec = JsQL.Math.EndCriteria(1000, 10, 1.0e-8, 1.0e-8, 1.0e-8)

# --- define initial values --- #
#initial_value = RawSviIntialValue().init
#a_init = min(total_variance1...)
initial_value = [0.1, 0.1, -0.01, 0.0, 0.1]
proj_initial_value = [0.1, 0.0, 0.1]
# --- define problem and optimization method--- #
p1 = JsQL.Math.Problem(svi_cost1, butterfly, copy(initial_value))
p1_noconstraint = JsQL.Math.Problem(svi_cost1, JsQL.Math.NoConstraint(), copy(initial_value))

proj_p1 = JsQL.Math.Problem(proj_svi_cost1, proj_butterfly, copy(initial_value))
proj_p1_noconstraint = JsQL.Math.Problem(proj_svi_cost1, JsQL.Math.NoConstraint(), copy(initial_value))

# --- minimize ---#
JsQL.Math.minimize!(om, p1, ec)
JsQL.Math.minimize!(om, p1_noconstraint, ec)
JsQL.Math.minimize!(om, proj_p1, ec)
JsQL.Math.minimize!(om, proj_p1_noconstraint, ec)
#### p2
arbitrage_free = JsQL.Math.JointConstraint(butterfly, calender_only)
proj_arbitrage_free = JsQL.Math.JointConstraint(proj_butterfly, proj_calender_only)
p2 = JsQL.Math.Problem(svi_cost2, arbitrage_free, copy(initial_value))
p2_noconstraint = JsQL.Math.Problem(svi_cost2, JsQL.Math.NoConstraint(), copy(initial_value))

proj_p2 = JsQL.Math.Problem(svi_cost2, proj_arbitrage_free, copy(initial_value))
proj_p2_noconstraint = JsQL.Math.Problem(svi_cost2, JsQL.Math.NoConstraint(), copy(initial_value))

JsQL.Math.minimize!(om, p2, ec)
JsQL.Math.minimize!(om, p2_noconstraint, ec)
JsQL.Math.minimize!(om, proj_p2, ec)
JsQL.Math.minimize!(om, proj_p2_noconstraint, ec)
####
# --- results --- #
svi1 = RawSvi(p1.currentValue)
svi1_noconstraint = RawSvi(p1_noconstraint.currentValue)
svi2 = RawSvi(p2.currentValue)
svi2_noconstraint = RawSvi(p2_noconstraint.currentValue)

proj_svi1 = ProjectedSviJw(proj_p1.currentValue)
proj_svi1_noconstraint = ProjectedSviJw(proj_p1_noconstraint.currentValue)
proj_svi2 = ProjectedSviJw(proj_p2.currentValue)
proj_svi2_noconstraint = ProjectedSviJw(proj_p2_noconstraint.currentValue)

fitted_vol1 = sqrt.( svi1.(log_strikes) / t1 )
fitted_vol1_noconstraint = sqrt.( svi1_noconstraint.(log_strikes) / t1 )
fitted_vol2 = sqrt.( svi2.(log_strikes) / t2 )
fitted_vol2_noconstraint = sqrt.( svi2_noconstraint.(log_strikes) / t1 )

proj_fitted_vol1 = sqrt.( proj_svi1.(log_strikes) / t1 )
proj_fitted_vol1_noconstraint = sqrt.( proj_svi1_noconstraint.(log_strikes) / t1 )
proj_fitted_vol2 = sqrt.( proj_svi2.(log_strikes) / t2 )
proj_fitted_vol2_noconstraint = sqrt.( proj_svi2_noconstraint.(log_strikes) / t1 )


#println("fited volatilties:  ", fitted_vol1)
#println("diff:  ", sum((svi1.(log_strikes) - total_variance1).^2.0))
# --- plot --- #

#p = plot(strikes, fitted_vol1, label = "fitted volatilities", seriestype = :line)
p = plot(strikes, fitted_vol1, label = "fitted volatilities", seriestype = :line)
plot!(p, strikes, fitted_vol1_noconstraint, label = "no constraint", seriestype = :line)
plot!(p, strikes, 0.01*vol1, label = "volatility data", seriestype = :scatter)

p = plot(strikes, fitted_vol2, label = "fitted volatilities", seriestype = :line)
plot!(p, strikes, fitted_vol2_noconstraint, label = "no constraint", seriestype = :line)
plot!(p, strikes, 0.01*vol2, label = "volatility data", seriestype = :scatter)

### p2 ###

JsQL.Math.test(butterfly, p1.currentValue)
JsQL.Math.test(arbitrage_free, p2.currentValue)