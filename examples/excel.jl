using XLSX
using BenchmarkTools

include("D:/Projects/Julia/FiccPricer/examples/utils.jl")

xl_file = "D:\\Projects\\Julia\\FiccPricer\\examples\\USD201217.xlsx"

IRS = XLSX.readdata(xl_file, "USD_IRS", "C50:N50")

XLSX.openxlsx(xl_file, enable_cache=false) do f
    sheet = f["sample"]
    for r in XLSX.eachrow(sheet)
        v1 = r[1]    
        println(v1)
    end
end