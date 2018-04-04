export SimplePolyhedraLibrary, SimplePolyhedron

"""
    SimplePolyhedraLibrary{T}

Default library for polyhedra of dimension larger than 1 ([`IntervalLibrary`](@ref) is the default for polyhedra of dimension 1).
The library implements the bare minimum and uses the fallback implementation for all operations.
"""
struct SimplePolyhedraLibrary{T} <: PolyhedraLibrary
end

similar_library(lib::SimplePolyhedraLibrary, d::FullDim, ::Type{T}) where T = default_library(d, T) # default_library allows to fallback to Interval if d is FullDim{1}

mutable struct SimplePolyhedron{N, T, HRepT<:HRepresentation{N, T}, VRepT<:VRepresentation{N, T}} <: Polyhedron{N, T}
    hrep::Nullable{HRepT}
    vrep::Nullable{VRepT}
    function SimplePolyhedron{N, T, HRepT, VRepT}(hrep::Union{HRepT, Void}, vrep::Union{VRepT, Void}) where {N, T, HRepT<:HRepresentation{N, T}, VRepT<:VRepresentation{N, T}}
        new{N, T, HRepT, VRepT}(hrep, vrep)
    end
end
function SimplePolyhedron{N, T, HRepT, VRepT}(hrep::HRepT) where {N, T, HRepT<:HRepresentation{N, T}, VRepT<:VRepresentation{N, T}}
    SimplePolyhedron{N, T, HRepT, VRepT}(hrep, nothing)
end
function SimplePolyhedron{N, T, HRepT, VRepT}(vrep::VRepT) where {N, T, HRepT<:HRepresentation{N, T}, VRepT<:VRepresentation{N, T}}
    SimplePolyhedron{N, T, HRepT, VRepT}(nothing, vrep)
end

library(::Union{SimplePolyhedron{N, T}, Type{<:SimplePolyhedron{N, T}}}) where {N, T} = SimplePolyhedraLibrary{T}()

function arraytype(p::SimplePolyhedron{N, T, HRepT, VRepT}) where{N, T, HRepT, VRepT}
    @assert arraytype(HRepT) == arraytype(VRepT)
    arraytype(HRepT)
end

similar_type(::Type{<:SimplePolyhedron{M, S, HRepT, VRepT}}, d::FullDim{N}, ::Type{T}) where {M, S, HRepT, VRepT, N, T} = SimplePolyhedron{N, T, similar_type(HRepT, d, T), similar_type(VRepT, d, T)}

function SimplePolyhedron{N, T, HRepT, VRepT}(hits::HIt...) where {N, T, HRepT, VRepT}
    SimplePolyhedron{N, T, HRepT, VRepT}(HRepT(hits...))
end
function SimplePolyhedron{N, T, HRepT, VRepT}(vits::VIt...) where {N, T, HRepT, VRepT}
    SimplePolyhedron{N, T, HRepT, VRepT}(VRepT(vits...))
end

# Need fulltype in case the use does `intersect!` with another element
SimplePolyhedron{N, T}(rep::Representation{N}) where {N, T} = SimplePolyhedron{N, T}(MultivariatePolynomials.changecoefficienttype(rep, T))
function SimplePolyhedron{N, T}(rep::HRepresentation{N, T}) where {N, T}
    HRepT = fulltype(typeof(rep))
    VRepT = dualtype(HRepT)
    SimplePolyhedron{N, T, HRepT, VRepT}(rep)
end
function SimplePolyhedron{N, T}(rep::VRepresentation{N, T}) where {N, T}
    VRepT = fulltype(typeof(rep))
    HRepT = dualtype(VRepT)
    SimplePolyhedron{N, T, HRepT, VRepT}(rep)
end

function polyhedron(rep::Representation{N}, ::SimplePolyhedraLibrary{T}) where {N, T}
    SimplePolyhedron{N, polytypefor(T)}(rep)
end

function Base.copy(p::SimplePolyhedron{N, T}) where {N, T}
    if !isnull(p.hrep)
        SimplePolyhedron{N, T}(get(p.hrep))
    else
        SimplePolyhedron{N, T}(get(p.vrep))
    end
end

function Base.intersect!(p::SimplePolyhedron{N}, ine::HRepresentation{N}) where N
    p.hrep = hrep(p) ∩ ine
    p.vrep = nothing
end
function convexhull!(p::SimplePolyhedron{N}, ext::VRepresentation{N}) where N
    p.vrep = convexhull(vrep(p), ext)
    p.hrep = nothing
end

hrepiscomputed(p::SimplePolyhedron) = !isnull(p.hrep)
function computehrep!(p::SimplePolyhedron)
    # vrep(p) could trigger an infinite loop if both vrep and hrep are null
    p.hrep = doubledescription(get(p.vrep))
end
function hrep(p::SimplePolyhedron)
    if !hrepiscomputed(p)
        computehrep!(p)
    end
    get(p.hrep)
end
vrepiscomputed(p::SimplePolyhedron) = !isnull(p.vrep)
function computevrep!(p::SimplePolyhedron)
    # hrep(p) could trigger an infinite loop if both vrep and hrep are null
    p.vrep = doubledescription(get(p.hrep))
end
function vrep(p::SimplePolyhedron)
    if !vrepiscomputed(p)
        computevrep!(p)
    end
    get(p.vrep)
end

function detecthlinearity!(p::SimplePolyhedron)
    p.hrep = removeduplicates(hrep(p))
end
function detectvlinearity!(p::SimplePolyhedron)
    p.vrep = removeduplicates(vrep(p))
end
function removehredundancy!(p::SimplePolyhedron)
    detectvlinearity!(p)
    detecthlinearity!(p)
    p.hrep = removehredundancy(hrep(p), vrep(p))
end
function removevredundancy!(p::SimplePolyhedron)
    detecthlinearity!(p)
    detectvlinearity!(p)
    p.vrep = removevredundancy(vrep(p), hrep(p))
end
