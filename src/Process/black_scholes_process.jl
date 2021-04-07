struct GeneralBlackScholesType <: BlackScholesType end
struct BlackScholesMertonType <: BlackScholesType end
struct BlackScholesDiscreteDividendType <: BlackScholesType end

struct GeneralizedBalckScholesProcess{Y1 <: YieldTermStructure, Y2 <: YieldTermStructure, 
    LC <: LocalVolTermStructure,
    B <:BlackVolTermStructure, D <: AbstractDiscretization, BST <: BlackScholesType}
    # BoB
    x0::Quote
    riskFreeRate::Y1
    dividendYield::Y2
    blackVolatility::B
    localVolatility::LC
    disc::D
    isStrikeDependent::Bool # hm....what would this mean..
    # 
    dividendScedule::Vector{Date}
    dividendTimes::Vector{Float64}
    dividendAmounts::Vector{Float64} # The values are something like 0.005, 0.0001

    blackScholesType::BST
end


function GeneralizedBlackScholesProcess(x0::Quote, riskFreeRate::Y1, dividendYield::Y2, 
                                blackVolatility::BlackConstantVol, 
                                disc::D = EulerDiscretization()) where {Y1 <: YieldTermStructure, Y2 <: YieldTermStructure, D <: AbstractDiscretization}
    # BoB                            
    localVolatility = LocalConstantVol(blackVolatility.referenceDate, black_vol(blackVolatility, 0.0, x0.value), blackVolatility.dc)

    return GeneralizedBlackScholesProcess{Y1, Y2, BlackConstantVol, D, GeneralBlackScholesType}(x0, riskFreeRate, dividendYield, 
                                    blackVolatility, localVolatility, disc, true, 
                                    Date[], Float64[], Float64[], 
                                    GeneralBlackScholesType())
end

function BlackScholesMertonProcess(x0::Quote, riskFreeRate::Y1, dividendYield::Y2,
    blackVolatility::BlackConstantVol, disc::D = EulerDiscretization()) where {Y1 <: YieldTermStructure, Y2 <: YieldTermStructure, D <: AbstractDiscretization}
    localVolatility = LocalConstantVol(blackVolatility.referenceDate, black_vol(blackVolatility, 0.0, x0.value), blackVolatility.dc)

    return GeneralizedBlackScholesProcess{Y1, Y2, BlackConstantVol, D, BlackScholesMertonType}(x0, riskFreeRate, dividendYield, 
                    blackVolatility, localVolatility, disc, true, 
                    BlackScholesMertonType())
end

function BlackScholesDiscreteDividendProcess(x0::Quote, riskFreeRate::Y1, blackVolatility::BlackConstantVol, 
                            dividendSchdule::Vector{Date}, dividendAmounts::Vector{Float64}, 
                            disc::D = EulerDiscretization()) where {Y1 <: YieldTermStructure, D <: AbstractDiscretization}
    localVolatility = LocalConstantVol(blackVolatility.referenceDate, black_vol(blackVolatility, 0.0, x0.value), blackVolatility.dc)
    refDate = blackVolatility.referenceDate
    dividendTimes = (dividendSchdule .-refDate) .|> x -> x.value
    return GeneralizedBlackScholesProcess{Y1, Y1, BlackConstantVol, D, BlackScholesDiscreteDividendType}
                    (x0, riskFreeRate, NullTermStructure(), 
                    blackVolatility, localVolatility, disc, true, 
                    dividendSchdule, dividendTimes, dividendAmounts,
                    BlackScholesDiscreteDividendType())
end
### forward price
function forward_price(process::GeneralizedBalckScholesProcess, T::Float64)
    riskFreeDiscount = discount(process.riskFreeRate, T)
    dividendDiscount = discount(process.dividendYield, T)
    forward = dividend_deduction(process, T) * dividendDiscount / riskFreeDiscount
    return forward
end

function dividend_deduction(process::GeneralizedBalckScholesProcess, T::Float64)
    riskFreeDiscount = discount(process.riskFreeRate, T)
    time_masking = process.dividendTimes <= T
    div_time = process.dividendTimes[time_masking]
    div_disc = map(z -> discount(process.riskFreeRate, z), div_time)
    amortized = sum(rocess.dividendAmounts[time_masking] .* div_disc)
    res = process.x0.value - amortized 
    return res
end

### make discrete dividend local vol process
function drift(process::GeneralizedBalckScholesProcess, t::Float64, x::Float64)
    sigma = diffusion(process, t, x)
    t1 = t + 0.0001
  
    return forward_rate(process.riskFreeRate, t, t1, ContinuousCompounding(), NoFrequency()).rate -
            forward_rate(process.dividendYield, t, t1, ContinuousCompounding(), NoFrequency()).rate -
            0.5 * sigma * sigma
end

diffusion(process::GeneralizedBalckScholesProcess, t::Float64, x::Float64) = local_vol(process.localVolatility, t, x)

state_variable(p::AbstractBlackScholesProcess)=p.x0

get_time(p::AbstractBlackScholesProcess, d::Date)= year_fraction(p.riskFreeRate.dc, reference_date(p.riskFreeRate), d)

"""
t = w + dt
"""
expectation(process::GeneralizedBlackScholesProcess, ::Float64, ::Float64, ::Float64) = error("not implemented")

apply(::GeneralizedBlackScholesProcess, x0::Float64, dx::Float64) = x0 * exp(dx)

function evolve(process::GeneralizedBlackScholesProcess, t::Float64, x::Float64, dt::Float64, dw::Float64)
    dividend_deduction(process, t + dt)
    if process.isStrikeDependent
        var = black_variance(process.blackVolatility, t + dt, 0.01) - black_variance(process.blackVolatility, t, 0.01)
        drift_ = (forward_rate(process.riskFreeRate, t, t + dt, ContinuousCompounding(), NoFrequency()).rate -
                forward_rate(process.dividendYield, t, t + dt, ContinuousCompounding(), NoFrequency()).rate) *
                dt - 0.5 * var
  
        return x * exp(sqrt(var) * dw + drift_) # plain vanilla formula
    else
        return apply(process, x, drift(process.disc, process, t, x, dt) + std_deviation(process, t, x, dt) * dw) # x + dx
    end
end