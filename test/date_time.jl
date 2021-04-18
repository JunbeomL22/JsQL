using JsQL
using JsQL.Time
using Dates

dtg = DateTimeGrid(Date(2021, 1, 1), Date(2021, 1, 5); mandDates = [Date(2021, 1, 2)])

p = Path(dtg, dtg.times*2.0)
println(p(0.02))
println(p(Date(2021, 2, 2)))
println(p(Date(2021, 1, 1), Date(2021, 1, 3)))


