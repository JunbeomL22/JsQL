using JsQL
using Dates

cal = JsQL.Time.SouthKoreaKrxCalendar()
eval_date = today()
settlement_date = eval_date + Day(2)
set_eval_date!(settings, eval_date)

times = [0.0, 0.5, 1.0, 2.0, 3.0]
rates = [0.0, 0.02, 0.022, 0.025, 0.03]
discounts = exp.(- times .* rates)
Lin = JsQL.Math.LinearInterpolation

risk_free_rate = ZeroCurve( settings.evaluation_date, times, rates, JsQL.Act365(), Lin() )

dividend_schedule = [Month(6), Month(18), Month(24)] .+ settings.evaluation_date
x0 = 3000.0
dividend_amounts  = [30., 50., 40.]

optionType = Put()
strike = 2500.0
vol = 0.20

dc = JsQL.Time.Act365()

mat_dates = Date[settings.evaluation_date + Dates.Month(6 * i) for i =1:6]

EuropeanExercises = EuropeanExercise.(mat_dates)

underlying = Quote(x0)

flatVolTS = BlackConstantVol(settlement_date, cal, vol, dc)

payoff = PlainVanillaPayoff(optionType, strike)

bsmProcess = BsmDiscreteDiv(underlying, risk_free_rate, flatVolTS, dividend_schedule, dividend_amounts)

fp = forward_price(bsmProcess, 1.0)

div = accumulated_dividend(bsmProcess, 0.0, 0.5)

discretization = EulerDiscretization()

diffusion(discretization, bsmProcess, 0.0, x0, 0.01)
