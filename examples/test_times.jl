#=
using FiccPricer.Times
using Dates

d = Date(2021, 1, 29)
cal = SouthKoreaKrxCalendar()
conv = ModifiedFollowing()

res = advance(Day(1), cal, d, conv)

println(res)

