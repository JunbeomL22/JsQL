include("D:\\FiccProgram\\JsQL\\test\\data.jl")
using JsQL.Time
using JsQL
using Dates


eval_date = Date(2021, 1, 4)
settlement_date = eval_date
set_eval_date!(settings, eval_date)

past = sofr_dict
#x= sort(collect(past), by=x->x[1])
effect = Date(2020, 10, 21)
mat = effect + Year(1) + Day(1)

tenor = TenorPeriod(Quaterly())
rule = DateGenerationBackwards()
cal = SouthKoreaSettlementCalendar()
conv = ModifiedFollowing()

schedule = Schedule(effect, mat, tenor, conv, rule, false, cal)

cal = JsQL.Time.USSettlementCalendar()
conv = JsQL.Time.ModifiedFollowing()
dc = JsQL.Time.Act360()

dates = [eval_date]
append!(dates, eval_date + ois_periods)
rates = [ois_zeros[1]]
rates = append!(rates, ois_zeros)

yts = ZeroCurve(dates, rates, JsQL.Act365()) # ois curve
fixing_period = TenorPeriod(Quaterly())
payment_period = TenorPeriod(Quaterly())

sofr = OvernightIndex("SOFR", fixing_period, payment_period, -1, JsQL.USDCurrency(), cal, dc, conv, yts, past)
#usd_libor_index(fixing_period, payment_period, yts)
#libor.pastFixings = past
leg = FloatingLeg(schedule, 100., sofr, Following())

for c in leg.coupons
    mixin = c.couponMixin
    println(mixin.fixingDate, ",  ", mixin.calcStartDate, ",  ", mixin.calcEndDate, ",  ", mixin.calcEndDate, 
    ",  rate: $(round(c.forecastedRate, digits=5)),  frac: $(round(c.spanningTime, digits = 5)),  amount: $(round(c.forecastedRate * c.spanningTime, digits=5))")
end
