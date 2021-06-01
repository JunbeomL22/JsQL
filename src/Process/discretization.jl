struct EulerDiscretization <: AbstractDiscretization end

drift(::EulerDiscretization, process::StochasticProcess1D, t::Float, x::Float, dt::Float) = drift(process, t, x) * dt
drift(::EulerDiscretization, process::StochasticProcess2D, t::Float, x::Vector{Float}, dt::Float) = drift(process, t, x) .* dt
diffusion(::EulerDiscretization, process::StochasticProcess1D, t::Float, x::Float, dw::Float) = diffusion(process, t, x) * dw
diffusion(::EulerDiscretization, process::StochasticProcess2D, t::Float, x::Vector{Float}, dw::Vector{Float}) = diffusion(process, t, x) * dw

function evolve(::EulerDiscretization, process::StochasticProcess1D, t::Float, x::Float, dt::Float, dw::Float)
    return x + drift(process, t, x) * dt + diffusion(process, t, x) * dw
end

function variance(::EulerDiscretization, process::StochasticProcess1D, t::Float, x::Float, dt::Float)
    σ = diffusion(process, t, x)
    return σ^2.0 * dt
end