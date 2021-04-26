using JSON
using Dates
using BenchmarkTools

function test()
    js = JSON.parsefile("D:\\FiccProgram\\Booking\\ir20210422.json")
    db_usdirs = filter(kv -> kv.second["ir_code"]=="IRSUSDUSD", js)
    usdirs_dv = [(Int(kv.second["day"]), kv.second["value"]) for kv in db_usdirs]
    days_value = sort(usdirs_dv, by=x->x[1])
    days = Day.(getindex.(days_value, 1))
    value = getindex.(days_value, 2)
end


