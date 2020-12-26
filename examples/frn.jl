using QuantLib
using XLSX
#using Plots
using Dates


include("D:/Projects/Julia/FiccPricer/examples/utils.jl")

xl_file = "D:\\Projects\\Julia\\FiccPricer\\examples\\USD201217.xlsx"
#xf = XLSX.readxlsx(xl_file)
#names = XLSX.sheetnames(xf)

eval_date = today()
settlement_date = eval_date + Day(3)
set_eval_date!(settings, eval_date)

tenor = Float64[0.0, 1/12, 3/12, 0.5, 1, 2, 3, 5, 7, 10, 15, 20, 30]
periods  = Period[Month(0), Month(1), Month(3), Month(6),
                Year(1), Year(2), Year(3), Year(5), Year(7), Year(10),
                Year(15), Year(20), Year(30)]
tenor_dates = periods + eval_date

#dates = XLSX.readdata(xl_file, "USD_IRS", "A2:A2")
IRS = XLSX.readdata(xl_file, "USD_IRS", "C50:N50")
f_irs = Float64[0.0, IRS[1, :]...] * 0.01
USD_Korea = XLSX.readdata(xl_file, "USD_Korea", "C50:N50")
f_korea = Float64[0.0, USD_Korea[1, :]...] * 0.01

spread = Float64[0.0005 * x for x in 1:20]

function frn_pricing(pd::Period, tn::Vector{Float64}, tn_dates::Vector{Date}, irs::Vector{Float64}, korea::Vector{Float64})
    f_irs = irs
    f_korea = korea

    irs_discount = map((x, y)->exp(-x*y), f_irs, tn)
    korea_discount = map((x, y)->exp(-x*y), f_korea, tn)

    irs_curve = InterpolatedDiscountCurve(tn_dates, irs_discount, QuantLib.Time.Actual365(), QuantLib.Math.LinearInterpolation())
    korea_curve = InterpolatedDiscountCurve(tn_dates, korea_discount, QuantLib.Time.Actual365(), QuantLib.Math.LinearInterpolation())

    cal = QuantLib.Time.TargetCalendar()
    cap_vol = ConstantOptionVolatility(3, cal, QuantLib.Time.ModifiedFollowing(), 0.0, QuantLib.Time.Actual365())
    libor_3m = usd_libor_index(QuantLib.Time.TenorPeriod(Dates.Month(3)), irs_curve)        

    frn = generate_floatingrate_bond(korea_curve, QuantLib.Time.Actual360(), Date(2020, 1, 2), 
                                        Date(2020, 1, 2) + pd, 0.008, libor_3m, 100., cap_vol)

    println("Discounting upto $(tn[end]),  NPV: ", npv(frn))
end

for i in 9:13
    frn_pricing(Year(20), tenor[1:i], tenor_dates[1:i], f_irs[1:i], f_korea[1:i])
end


