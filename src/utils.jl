
"""
    string2wrappergeomtype(class::String)::Type{<: GI.WrapperGeometry}

Converts an R `sfg` class string to the corresponding GeoInterface.jl wrapper geometry type.
This does not include any dimensionality information (`hasZ, hasM`) or CRS information, which is added 
later.
"""
function string2wrappergeomtype(class::String)
    if class == "POINT"
        GI.Point
    elseif class == "LINESTRING"
        GI.LineString
    elseif class == "POLYGON"
        GI.Polygon
    elseif class == "MULTIPOINT"
        GI.MultiPoint
    elseif class == "MULTILINESTRING"
        GI.MultiLineString
    elseif class == "MULTIPOLYGON"
        GI.MultiPolygon
    elseif class == "GEOMETRYCOLLECTION"
        GI.GeometryCollection
    elseif class == "GEOMETRY"
        GI.Wrappers.WrapperGeometry
    else
        error("Unknown geometry class: $class")
    end
end

string2wrappergeomtype(class::Symbol) = string2wrappergeomtype(String(class))

"""
    has_zm(dims::String)::(hasZ::Bool, hasM::Bool)

Returns `hasZ, hasM` for the given `dims` string.  That string
is expected to be `"XY"`, `"XYZ"`, `"XYZM"`, or `"XYM"`, which
occur in the first class of an `sfg` object.
"""
function has_zm(dims::String)
    hasZ, hasM = if dims == "XY"
        false, false
    elseif dims == "XYZ"
        true, false
    elseif dims == "XYZM"
        true, true
    elseif dims == "XYM"
        false, true
    else
        error("Unknown dimensions: $dims.  Expected `\"XY[Z[M]]\"`")
    end
    return hasZ, hasM
end


function has_zm(dims::Symbol)
    hasZ, hasM = if dims == :XY
        false, false
    elseif dims == :XYZ
        true, false
    elseif dims == :XYZM
        true, true
    elseif dims == :XYM
        false, true
    else
        error("Unknown dimensions: $dims.  Expected `\"XY[Z[M]]\"`")
    end
    return hasZ, hasM
end




"""
    get_sf_crs(s)

Get the CRS from an R `sfc` object as a `GeoFormatTypes` object with the CRS trait.
"""
function get_sf_crs(s::Ptr{RCall.VecSxp})
    crs_dict= RCall.rcall(R"st_crs", s)
    return get_sf_crs(crs_dict)
end

get_sf_crs(o::RObject{RCall.VecSxp}) = get_sf_crs(o.ptr)

function get_sf_crs(o::RCall.OrderedDict)
    ks = keys(o)
    return if :wkt in ks # prefer fully realized WKT
        GFT.ESRIWellKnownText(GFT.CRS(), o[:wkt])
    elseif :epsg in ks # if EPSG code is available, use that
        GFT.EPSG(o[:epsg])
    else # if nothing is available, return nothing -- TODO should this even warn?
        @warn "No good CRS found in the dict, setting it to `nothing`"
        nothing
    end
end

