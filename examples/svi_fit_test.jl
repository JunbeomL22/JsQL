using FiccPricer
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

# --- define constraints  --- #
butterfly_only = RawSviButterFlyConstraint()
base_constraint = RawSviBaseConstraint()
butterfly = FiccPricer.Math.JointConstraint(butterfly_only, base_constraint)
calender = CalendarConstraint(log.(strikes), (0.01 * vol1).^2.0 * t1)
joint_arbitrage_free = FiccPricer.Math.JointConstraint(butterfly, calender)

# --- define initial values --- #
initial_value = RawSviIntialValue().init
a_init = min(total_variance1...)
initial_value = [0.1, 0.1, -0.01, 0.0, 0.1]
# --- define problem and optimization method--- #
p1 = FiccPricer.Math.Problem(svi_cost1, butterfly, copy(initial_value))
p1_noconstraint = FiccPricer.Math.Problem(svi_cost1, FiccPricer.Math.NoConstraint(), copy(initial_value))

#om = FiccPricer.Math.LevenbergMarquardt()#(1.0e-5, 1.0e-5, 1.0e-5, true)
om = FiccPricer.Math.Simplex(0.01)
ec = FiccPricer.Math.EndCriteria(1000, 10, 1.0e-8, 1.0e-8, 1.0e-8)

# --- minimize ---#
FiccPricer.Math.minimize!(om, p1, ec)
FiccPricer.Math.minimize!(om, p1_noconstraint, ec)

# --- results --- #
svi1 = RawSvi(p1.currentValue)
svi1_noconstraint = RawSvi(p1_noconstraint.currentValue)

fitted_vol1 = sqrt.( svi1.(log_strikes) / t1 )
fitted_vol1_noconstraint = sqrt.( svi1_noconstraint.(log_strikes) / t1 )

#println("fited volatilties:  ", fitted_vol1)
#println("diff:  ", sum((svi1.(log_strikes) - total_variance1).^2.0))
# --- plot --- #

#p = plot(strikes, fitted_vol1, label = "fitted volatilities", seriestype = :line)
p = plot(strikes, fitted_vol1, label = "fitted volatilities", seriestype = :line)
plot!(p, strikes, fitted_vol1_noconstraint, label = "no constraint", seriestype = :line)
plot!(p, strikes, 0.01*vol1, label = "volatility data", seriestype = :scatter)

FiccPricer.Math.test(butterfly, p1.currentValue)