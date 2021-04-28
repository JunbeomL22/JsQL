include("D:\\FiccProgram\\JsQL\\test\\libor_data.jl")
using JsQL.Time
using JsQL
using Dates

past = usd3m_past_fixing
effect = Date(2021, 1, 1)
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

Lin = JsQL.Math.LinearInterpolation

yts = ZeroCurve(dates, rates, JsQL.Act365(), Lin() )

fixing_period = TenorPeriod(Quaterly())
payment_period = TenorPeriod(Quaterly())

libor = usd_libor_index(fixing_period, payment_period, yts)
libor.pastFixings = past
function earliest_intrerval(idx::InterestRateIndex, d::Date, schedule::Schedule)
    payDays = idx.paymentDays
    paydate = Date(0)
    count = 1
    len = length(schedule)
    while d > paydate && count <= len
        count += 1
        paydate = adjust(idx.cal, idx.paymentConvention, schedule[count] + Day(payDays))
    end
    return (schedule[count-1], schedule[count], paydate)
end

function fixing_and_value(idx::InterestRateIndex, start_date::Date, end_date::Date)
    past = idx.pastFixings
    fixing_dates = [keys(filter(d ->  start_date <= d.first <= end_date, past))...] # Vector
    fixingDays = idx.fixingDays
        
    function interval(fixing::Date, fixing_days::Int, cal::BusinessCalendar)
        s = advance(Day(-fixing_days), cal, fixing)
        e = advance(Day(1), cal, s)
        return s, e
    end
    return map(x->(x, interval(x, fixingDays, idx.jointCalendar)...), fixing_dates)
end

v = fixing_and_value(libor, schedule.dates[1], schedule.dates[2])