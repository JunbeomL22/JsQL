include("D:\\FiccProgram\\JsQL\\test\\data.jl")
using JsQL.Time
using JsQL
using Dates

past = usd3m_past_fixing
effect = Date(2021, 1, 6)
mat = effect + Year(1)+Day(1)
tenor = TenorPeriod(Quaterly())
rule = DateGenerationBackwards()
cal = SouthKoreaSettlementCalendar()
conv = ModifiedFollowing()

schedule = Schedule(effect, mat, tenor, conv, rule, false, cal)

cal = JsQL.Time.SouthKoreaSettlementCalendar()
eval_date = effect
settlement_date = eval_date
set_eval_date!(settings, eval_date)

dates = eval_date + Day.(round.([0.0, 0.25, 0.5, 0.75, 1.0] .* 365))
rates = [1.0, 0.2, 0.2, 0.2, 0.2]

yts = ZeroCurve(dates, rates, JsQL.Act365())

fixing_period = TenorPeriod(Quaterly())
payment_period = TenorPeriod(Quaterly())

libor = usd_libor_index(fixing_period, payment_period, yts)
libor.pastFixings = past

leg = FloatingLeg(schedule, 100., libor, Following())

for c in leg.coupons
    mixin = c.couponMixin
    println(mixin.fixingDate, ", ", mixin.calcStartDate, ", ", mixin.calcEndDate, ", ", mixin.calcEndDate)
end