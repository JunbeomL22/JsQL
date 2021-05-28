using Dates

struct PowerSpreadPayoff <: AbstractPayoff
    coupon::Float64
    floor::Float64
    cap::Float64
    leverage::Float64 # normally 15
    startDate::Date
    endDate::Date
    participate::Vector{Float64} # [1.0, -1.0] normally where cd and ktb are the path
    performer::Vector{PerformanceType}
end

function (po::PowerSpreadPayoff)(path::Path)
    pathInterval = path(po.startDate, po.endDate)[1:2, :]
    cd = po.performer[1](pathInterval[1, :])
    ktb = po.performer[2](pathInterval[2, :])

    res = po.coupon + po.leverage*(po.participate[1]*cd + po.participate[2]*ktb)
    res = max(res, po.floor)
    res = min(res, po.cap)
    return res
end