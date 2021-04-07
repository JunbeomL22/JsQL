struct EulerDiscretization <: AbstractDiscretization end

drift(::EulerDiscretization, process::StochasticProcess1D, t::Float64, x::Float64, dt::Float64) = drift(process, t, x) * dt

diffusion(::EulerDiscretization, process::StochasticProcess1D, t::Float64, x::Float64, dt::Float64) = diffusion(process, t, x) * sqrt(dt)

function variance(::EulerDiscretization, process::StochasticProcess1D, t::Float64, x::Float64, dt::Float64)
    σ = diffusion(process, t, x)
    return σ^2.0 * dt
end