struct Monomial <: LsmBasisSystemPolynomType end
struct MultiMonomial <: LsmBasisSystemPolynomType end

struct MonomialFunction <: LsmBasisSystemFunction
    order::Int
end

function (m::MonomialFunction)(x::Float64)
    ret = 1.0
    @simd for i = 1:m.order
        ret *= x
    end

    return ret
end

get_type(::Monomial) = MonomialFunction{Int}

function path_basis_system!(::Monomial, order::Int, v::Vector)
    @simd for i = 1:order + 1
        @inbounds v[i] = MonomialFunction(i - 1) # functor generated
    end

    return v
end

###
###

struct MultiMonomialFunction <: LsmBasisSystemFunction
    order::Vector{Int}
end

function (m::MultiMonomialFunction)(x::Vector{Float64})
    ret = 1.0
    dimension = length(m.order)
    if length(x) != dimension
        error("The dimensions are not matched in MultiMonomialFunction")
    @simd for i = 1:dimension
        @simd for j = 1:m.order[i]
            ret *= x[j]
    end

    return ret
end

function path_basis_system!(::MultiMonomial, order::Int, v::Vector)
    error("not implemented")
end