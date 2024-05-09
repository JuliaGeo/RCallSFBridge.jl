# This file defines all the methods required to copy R geometries into Julia.
"""
    _tuplepointtype(::Type{GI.WrapperGeometry{hasZ, hasM}}, crs)

Returns a fully specified type for the given geometry type, assuming 
that geometries are stored in vectors except for Points which are tuples
of Float64.
"""
function _tuplepointtype end
_tuplepointtype(::Type{GI.Point{hasZ, hasM}}, crs::CRSType = nothing) where {hasZ, hasM, CRSType} = GI.Point{hasZ, hasM, NTuple{2+hasZ+hasM, Float64}, CRSType}
# The point type is explicit here because we don't want to bloat linear rings with points that have CRS.
# However, if the initial geometry has points, then 
_tuplepointtype(::Type{GI.LineString{hasZ, hasM}}, crs::CRSType = nothing) where {hasZ, hasM, CRSType} = GI.LineString{hasZ, hasM, Vector{GI.Point{hasZ, hasM, Tuple{Float64, Float64}, Nothing}}, Nothing, CRSType}
_tuplepointtype(::Type{GI.LinearRing{hasZ, hasM}}, crs::CRSType = nothing) where {hasZ, hasM, CRSType} = GI.LinearRing{hasZ, hasM, Vector{GI.Point{hasZ, hasM, Tuple{Float64, Float64}, Nothing}}, Nothing, CRSType}
_tuplepointtype(::Type{GI.MultiLineString{hasZ, hasM}}, crs::CRSType = nothing) where {hasZ, hasM, CRSType} = GI.MultiLineString{hasZ, hasM, Vector{_tuplepointtype(GI.LineString{hasZ, hasM}, crs)}, Nothing, CRSType}
_tuplepointtype(::Type{GI.Polygon{hasZ, hasM}}, crs::CRSType = nothing) where {hasZ, hasM, CRSType} = GI.Polygon{hasZ, hasM, Vector{_tuplepointtype(GI.LinearRing{hasZ, hasM}, crs)}, Nothing, CRSType}
_tuplepointtype(::Type{GI.MultiPolygon{hasZ, hasM}}, crs::CRSType = nothing) where {hasZ, hasM, CRSType} = GI.MultiPolygon{hasZ, hasM, Vector{_tuplepointtype(GI.Polygon{hasZ, hasM}, crs)}, Nothing, CRSType}

# First, define conversions for sfg geometries:
# Conversion chain for `sfg` geometries
# This function will extract the type of the vector, then convert it to 
# the appropriate GeoInterface type.
# This is type unstable anyway so I don't think it matters if it's more type unstable.
function RCall.rcopytype(::Type{RCall.RClass{:sfg}}, s::Ptr{RCall.VecSxp})
    classes = RCall.rcopy(Array{Symbol}, RCall.getclass(s))
    dims = classes[1]
    type = classes[2]
    hasZ, hasM = has_zm(dims)
    GIType = string2wrappergeomtype(type){hasZ, hasM}
    # sfg geometries don't have a CRS, so we pass `nothing` as the CRS argument
    return GIType
end
# These functions perform the actual copying.  Since the data structure is different
# for each function, they have to be defined separately.
function RCall.rcopy(::Type{GI.Point{hasZ, hasM, Tuple{Float64, Float64}, CRSType}}, s::Ptr{RCall.VecSxp}, crs::CRSType = nothing) where {hasZ, hasM, CRSType}
    return GI.Point{hasZ, hasM, Tuple{Float64, Float64}, CRSType}(RCall.rcopy(Tuple{Float64, Float64}, s), crs)
end

function RCall.rcopy(::Type{GI.LineString{hasZ, hasM}}, s::Ptr{RCall.VecSxp}, crs::CRSType = nothing) where {hasZ, hasM, CRSType}
    return _tuplepointtype(GI.LineString{hasZ, hasM}, crs)(
        _pointify_matrix_by_row(
            GI.Point{hasZ, hasM}, 
            rcopy(Matrix{Float64}, ls)
        ), 
        crs
    )
end

function RCall.rcopy(::Type{GI.LinearRing{hasZ, hasM}}, s::Ptr{RCall.VecSxp}, crs::CRSType = nothing) where {hasZ, hasM, CRSType}
    return _tuplepointtype(GI.LinearRing{hasZ, hasM}, crs)(
        _pointify_matrix_by_row(
            GI.Point{hasZ, hasM}, 
            rcopy(Matrix{Float64}, s)
        ), 
        crs
    )
end

function RCall.rcopy(::Type{GI.MultiLineString{hasZ, hasM}}, mls::Ptr{RCall.VecSxp}, crs::CRSType = nothing) where {hasZ, hasM, CRSType}
    return _tuplepointtype(GI.MultiLineString{hasZ, hasM}, crs)(
        [RCall.rcopy(GI.LineString{hasZ, hasM}, ls, crs) for ls in mls], 
        crs
    )
end

function RCall.rcopy(::Type{GI.Polygon{hasZ, hasM}}, s::Ptr{RCall.VecSxp}, crs::CRSType = nothing) where {hasZ, hasM, CRSType}
    # return _tuplepointtype(GI.Polygon{hasZ, hasM}, crs)(
    #     [RCall.rcopy(GI.LinearRing{hasZ, hasM}, ls, crs) for ls in s], 
    #     crs
    # )
    geoms = [_tuplepointtype(GI.LinearRing{hasZ, hasM}, crs)(
        _pointify_matrix_by_row(GI.Point{hasZ, hasM}, mat),
        nothing,
        crs)
        for mat in rcopy(Array, s)
    ]
    return _tuplepointtype(GI.Polygon{hasZ, hasM}, crs)(
        geoms, 
        nothing,
        crs
    )
end

function RCall.rcopy(::Type{GI.MultiPolygon{hasZ, hasM}}, mpols::Ptr{RCall.VecSxp}, crs::CRSType = nothing) where {hasZ, hasM, CRSType}
    return _tuplepointtype(GI.MultiPolygon{hasZ, hasM}, crs)(
        [RCall.rcopy(GI.Polygon{hasZ, hasM}, poly, crs) for poly in mpols], 
        nothing,
        crs
    )
end

# TODO: implement GeometryCollection support
# This is slightly more complicated since you would have to effectively RCopy with no type stability

#=
## SFC support

`sfc` objects are collections of `sfg`s, so we can simply use the `sfg` methods above 
for the meat of the conversion.  
=#

function #=RCall.=#___rcopytype(::Type{RCall.RClass{:sfc}}, sfc::Ptr{RCall.VecSxp})
    # Get dimensions
    available_dims = unique!(sort!(RCall.rcopy.((Symbol,), first.(RCall.getclass.(sfc)))))
    @assert length(available_dims) == 1 "We don't support copying mixed-dimension geometry yet."
    dims = has_zm(only(available_dims))
    # type = RCall.rcopy(Symbol, RCall.getclass(sfc)[1])
    # return string2wrappergeomtype(type)
end

