struct Monomial <: LsmBasisSystemPolynomType end
#struct MultiMonomial <: LsmBasisSystemPolynomType end

#=
struct MonomialFunction <: LsmBasisSystemFunction
    order::Int
end
=#
struct MonomialFunction <: LsmBasisSystemFunction
    order::Vector{Int}
end
#=
function (m::MonomialFunction)(x::Float64)
    ret = 1.0
    @simd for i = 1:m.order
        ret *= x
    end

    return ret
end
=#
"""
m::MultiMonomialFunction)(x::Vector{Float64}) \n
If m.order == [2,0,1] and x = [w,y,z], it returns w^2*z
"""
function (m::MonomialFunction)(x::Vector{Float64})
    ret = 1.0
    dimension = length(m.order)
    if length(x) != dimension
        error("The dimensions are not matched in MonomialFunction")
    end
    @simd for i = 1:dimension
        ret *= x[i]^m.order[i]
    end

    return ret
end

get_type(::Monomial) = MonomialFunction{Vector{Int}}
#get_type(::MultiMonomial) = MultiMonomialFunction{Vector{Int}}
#=
function path_basis_system!(::Monomial, order::Int, v::Vector, dimension::Int = -1)
    @simd for i = 1:order + 1
        @inbounds v[i] = MonomialFunction(i - 1) # functor generated
    end
    return v
end
=#
function path_basis_system!(::Monomial, order::Int, v::Vector, dimension::Int = -1)
    dimension != - 1 || error("The dimension is not defined, 1209dcj")
    indices = cumulted_index_vector(order, dimension)
    resize!(v, length(indices))
    #v = Vector{MultiMonomialFunction}(undef, length(indices))
    @inbounds @simd for i in eachindex(indices)
        v[i] = MultiMonomialFunction(indices[i])
    end
    return v
end

"""
If order = 2, dimension =3 \n
it returns [2, 0, 0], [0, 2, 0], [0, 0, 2], [1, 1, 0], [0, 1, 1], [1, 0, 1] \n
It is recommended to cache this function
"""
function generate_index_vector(order::Int, dimension::Int)
    # base case 
    if order == 0
        return [zeros(Int, dimension)]
    end

    token = Vector{Int}(undef, dimension)
    number_of_basis = binomial(dimension + order - 1 , dimension - 1)
    ret = fill(zeros(Int, dimension), number_of_basis)

    if order == 1
        @simd for i=1:dimension
            token = zeros(Int, dimension)
            token[i] = 1
            ret[i] = token
        end
        return ret
    end
    # other cases
    previous_index  = generate_index_vector(order - 1, dimension)
    base_index      = generate_index_vector(1, dimension)

    k = 1
    @inbounds @simd for i in eachindex(previous_index)
        @simd for j in eachindex(base_index)
            token = previous_index[i] + base_index[j]
            if ~(token in ret)
                ret[k] = token
                k +=1
            end
        end 
    end
    return ret
end
"""
cumulted_index_vector(order=2, dimension=2) returns \n
[0, 0], [0, 1], [1,0], [2, 0], [1, 1], [0, 2]
"""
function cumulted_index_vector(order::Int, dimension::Int)
    ret  = Vector{Vector{Int}}[]
    dimension >= 1 || order >= 0 || error("dimension is not positive or order is negative, 0x0x132")

    @inbounds @simd for i = 0:order
       ret = vcat(ret,  generate_index_vector(i, dimension))
    end
    return ret
end

