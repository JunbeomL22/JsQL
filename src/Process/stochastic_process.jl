evolve(process::StochasticProcess1D, t0::Float64, x0::Float64, dt::Float64, dw::Float64) =
    apply(process, expectation(process, t0, x0, dt), std_deviation(process, t0, x0, dt) * dw) # dw ~ N(0, 1)

apply(::StochasticProcess1D, x0::Float64, dx::Float64) = x0 + dx

std_deviation(process::StochasticProcess1D, t0::Float64, x0::Float64, dt::Float64) = diffusion(process.disc, process, t0, x0, dt)

variance(process::StochasticProcess1D, t0::Float64, x0::Float64, dt::Float64) = variance(process.disc, process, t0, x0, dt)