include("D:\\FiccProgram\\JsQL\\test\\libor_data.jl")

using JsQL
using JsQL.Time

set_eval_date!(settings, today())
eval_date = settings.evaluation_date

tenors = eval_date + Month.([6*i for i = 0:8])
rates = [0.0, 0.01, 0.012, 0.013, 0.014, 0.015, 0.016, 0.016, 0.016]
yts = ZeroCurve(tenors, rates)

fixing_period = TenorPeriod(Quaterly())
payment_period = TenorPeriod(Quaterly())


libor = usd_libor_index(fixing_period, payment_period, yts)
println(zero_rate(libor.yts, 7.0).rate)
println( value_date(libor, Date(2021, 4, 10)))
println(fixing_date(libor, Date(2021, 4, 10)))
discount(yts, Date(2019, 1, 1))