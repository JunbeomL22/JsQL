using JsQL
using JsQL.Time
using Dates

set_eval_date!(settings, today())
eval_date = settings.evaluation_date
issueDate = eval_date
maturity  = eval_date + Year(3) - Day(1)
tenor_period = TenorPeriod(Quaterly())
date_generation = DateGenerationBackwards()
schedule = Schedule(issueDate, maturity, tenor_period, Following(), date_generation)

fixingDays = 0

bond = FixedCouponBond(1, 100.0, schedule, 0.0, Act365(), Following(), issueDate, SouthKoreaSettlementCalendar(), DiscountingBondEngine())

tenors = eval_date + Month.([6*i for i = 0:8])
rates = [0.0, 0.01, 0.012, 0.013, 0.014, 0.015, 0.016, 0.016, 0.016]
yts = ZeroCurve(tenors, rates)
pe = DiscountingBondEngine(yts)
_calculate!(pe, bond)

println(bond.results)
#dirty_price(pe, bond, eval_date)

duration(bond.cashflows, pe.pricingCurve, eval_date)

