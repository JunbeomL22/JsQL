using JsQL
using Random
using Dates
using BenchmarkTools
using LinearAlgebra

ref_date = Date(2021, 1, 2)
dates = [ref_date + Month(6*i) for i =0:2]
sigma = [0.02, 0.02, 0.02]
rates = [0.01, 0.01, 0.01]

yts = ZeroCurve(dates, rates)
vol = TimeStepVolatility(ref_date, dates, sigma)
dtg = JsQL.Time.DateTimeGrid(ref_date, ref_date + Year(20), mandDates = dates)
x1 = OneFactorGsrProcess(dtg, yts, 0.1, vol)

corr = Matrix{Float}(1.0I, 2, 2)
corr[1, 2] = corr[2, 1] = 0.95
rng = MersenneTwister(0)





PathGenerator
#process = OneFactorGsrProcess(dtg, )