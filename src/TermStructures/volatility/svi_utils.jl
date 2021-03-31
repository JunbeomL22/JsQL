const SVI_BUMP = 1.0e-5

function ssvi_to_jw(ρ::Float64, θ::Float64, ϕ::Phi, t::Float64) where {Phi <: SsviPhi}
    v = θ/t
    ψ = 0.5 * ρ * sqrt(θ) *ϕ(θ)
    p = 0.5 * ρ * sqrt(θ) *ϕ(θ) * (1.0 - ρ)
    c = 0.5 * ρ * sqrt(θ) *ϕ(θ) * (1.0 + ρ)
    vt=θ/t * (1.0-ρ^2.0)
    return v, ψ, p, c, vt
end

function raw_to_jw(a::Float64, b::Float64, ρ::Float64, m::Float64, σ::Float64, t::Float64)
    v = ( a + b * ( -ρ*m + sqrt(m^2.0 + σ^2.0) ) ) /t
    ω = v*t
    ψ = b / (2.0sqrt(ω)) * ( -m / sqrt(m^2.0 + σ^2.0) + ρ)
    p = b(1.0 - ρ)/sqrt(ω)
    c = b(1.0 + ρ)/sqrt(ω)
    vt = (1.0 + b*σ*sqrt(1.0-ρ^2.0) )/t
    return v, ω, ψ, p, c, vt
end

function jw_to_raw(v::Float64, ψ::Float64, p::Float64, c::Float64, vt::Float64, t::Float64)
    ω = v*t
    b = 0.5sqrt(ω)(c+p)
    ρ = 1.0 - p*sqrt(ω)/b
    β = ρ - 2 *ψ* sqrt(ω)/b
    abs(β) < 1.0 || error("|β| > 1 in transforming parameters from JW to raw SVI")
    α = sign(β) *sqrt(β^(-2.0) -1.0)
    m = (v-vt)*t
    m /= b
    m /= -ρ + sign(α)*sqrt(1.0+α^2.0) - α *sqrt(1.0 - ρ^2.0)
    if m ≈ 0.0
        σ = (v*t-a)/b
    else
        σ = α*m
    end
    a = vt*t - b*σ*sqrt(1.0-ρ^2.0)
    return a, b, ρ, m, σ
end

function ssvi_to_raw(ρ::Float64, θ::Float64, ϕ::Phi, t::Float64) where {Phi <: SsviPhi}
    v, ω, ψ, p, c, vt = ssvi_to_jw(ρ, θ, ϕ, t)
    a, b, ρ, m, σ     = jw_to_raw(v, ψ, p, c, vt, t)
    return a, b, ρ, m, σ
end
