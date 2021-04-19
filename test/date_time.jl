#using JsQL
using JsQL.Time
using Dates

startDate = Date(2021, 4, 22)
endDate = startDate + Year(3)
tp = TenorPeriod(Quaterly())
conv = Following()
rule = DateGenerationBackwards()
rule_forward = DateGenerationBackwards()
cal = SouthKoreaSettlementCalendar()
eom = false
d = Date(2022, 6, 18)
schedule = Schedule(startDate, endDate, tp, conv, conv, rule_forward, eom)













#
#
#
#=
dtg = DateTimeGrid(Date(2021, 1, 1), Date(2021, 1, 4); mandDates = [Date(2021, 1, 2)])
pt = Path(dtg)
p = Path(dtg, [dtg.times*1.0, dtg.times*2.0] )
println(p.dtg.times); p.values

w = Worst()

println(w(p.values))
println(p(0.02))
println(p(Date(2021, 2, 2)))
println(p(Date(2021, 1, 1), Date(2021, 1, 3)))
=#