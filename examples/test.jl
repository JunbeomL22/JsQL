using FiccPricer

#=
compound = 1.05
dc = Act360()
comp = SimpleCompounding()
time_frac = 1.0
freq = NoFrequency()
ir = implied_rate(1.05, dc, comp, time_frac, freq)
dump(ir)
=#

x=y=s=Float64[]
func = FiccPricer.Math.LinearInterpolation
v = func()

dump(v)

x = Float64[1., 2., 3.]
y = Float64[2., 4., 6.]

interp = func(x, y)

println(FiccPricer.Math.value(interp, 1.5))
println(FiccPricer.Math.value(interp, .5))
println(FiccPricer.Math.value_flat_outside(interp, 5.))
println(FiccPricer.Math.value(interp, 5.))
