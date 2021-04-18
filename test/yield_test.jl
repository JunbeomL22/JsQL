using JsQL
using Dates

cal = JsQL.Time.SouthKoreaSettlementCalendar()
eval_date = today()
settlement_date = eval_date
set_eval_date!(settings, eval_date)

dates = eval_date + Day.(round.([0.0, 0.25, 0.5, 0.75, 1.0] .* 365))
rates = [1.0, 0.2, 0.2, 0.2, 0.2]

Lin = JsQL.Math.LinearInterpolation

rf = ZeroCurve(dates, rates, JsQL.Act365(), Lin() )

println(discount(rf, Date(2021, 5, 5)))

rf.referenceDate += Day(1)

println(discount(rf, Date(2021, 5, 5)))


