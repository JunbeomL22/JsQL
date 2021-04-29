struct LogBsDiscreteDiv <: BlackScholesType end

function drift(process::BlackScholes, ::LogBsDiscreteDiv, t::Float64, x::Float64)
    t1 = t + 0.0001
    rate_forward = forward_rate(process.riskFreeRate, t, t1, ContinuousCompounding(), NoFrequency()).rate 
    σ = diffusion(process, t, x)
    return rate_forward - σ^2.0/2.0
end


diffusion(process::BlackScholes, ::LogBsDiscreteDiv, t::Float64, x::Float64) = local_vol(process.localVolatility, t, x) 

initial_value(p::AbstractBlackScholesProcess)=p.initialValue


function evolve(process::BlackScholes, t::Float64, x::Float64, dt::Float64, dw::Float64)
    dividend = accumulated_dividend(process, t, t + dt)

    return  x + drift(process.disc, process, t, x, dt) + diffusion(process.disc, t, x, dt) * dw - dividend
    
end