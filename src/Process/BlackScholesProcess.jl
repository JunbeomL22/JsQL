struct GeneralBlackScholesType <: BlackScholesType end
struct BlackScholesMertonType <: BlackScholesType end

struct GeneralizedBalckScholesProcess{Y1 <: YieldTermStructure, Y2 <: YieldTermStructure, 
    B <:BlackVolTermStructure, D <: AbstractDiscretization, BST <: BlackScholesType}
    x0::Quote
    riskFreeRate::Y1
    dividendYield::Y2
    blackVolatility::B
    localVolatility::LocalConstantVol
    disc::D
    isStrikeDependent::Bool
    blackScholesType::BST
end

function GeneralizedBlackScholesProcess(x0::Quote, riskFreeRate::Y1, dividendYield::Y2, blackVolatility::BlackConstantVol, 
    disc::D = EulerDiscretization()) where {Y1 <: YieldTermStructure, Y2 <: YieldTermStructure, D <: AbstractDiscretization}
    localVolatility = LocalConstantVol(blackVolatility.referenceDate, black_vol(blackVolatility, 0.0, x0.value), blackVolatility.dc)

    return GeneralizedBlackScholesProcess{Y1, Y2, BlackConstantVol, D, GeneralBlackScholesType}(x0, riskFreeRate, dividendYield, blackVolatility, localVolatility, disc, true, GeneralBlackScholesType())
end

function BlackScholesMertonProcess(x0::Quote, riskFreeRate::Y1, dividendYield::Y2,
    blackVolatility::BlackConstantVol, disc::D = EulerDiscretization()) where {Y1 <: YieldTermStructure, Y2 <: YieldTermStructure, D <: AbstractDiscretization}
    localVolatility = LocalConstantVol(blackVolatility.referenceDate, black_vol(blackVolatility, 0.0, x0.value), blackVolatility.dc)

    return GeneralizedBlackScholesProcess{Y1, Y2, BlackConstantVol, D, BlackScholesMertonType}(x0, riskFreeRate, dividendYield, blackVolatility, localVolatility, disc, true, BlackScholesMertonType())
end

function drift(process::GeneralizedBalckScholesProcess, t::Float64, x::Float64)
    sigma = diffusion(process, t, x)
    t1 = t + 0.0001
  
    return forward_rate(process.riskFreeRate, t, t1, ContinuousCompounding(), NoFrequency()).rate -
            forward_rate(process.dividendYield, t, t1, ContinuousCompounding(), NoFrequency()).rate -
            0.5 * sigma * sigma
end

diffusion(process::GeneralizedBalckScholesProcess, t::Float64, x::Float64) = local_vol(process.localVolatility, t, x)