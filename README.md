# RCallSFBridge

[![Build Status](https://github.com/JuliaGeo/RCallSFBridge.jl/actions/workflows/CI.yml/badge.svg?branch=main)](https://github.com/JuliaGeo/RCallSFBridge.jl/actions/workflows/CI.yml?query=branch%3Amain)

This package is an integration layer between R's `sf` package and Julia's `GeoInterface` ecosystem.  It defines [RCall.jl](https://github.com/JuliaInterop/RCall.jl) methods to materialize `sfc` and `sfg` objects as [GeoInterface.jl](https://github.com/JuliaGeo/GeoInterface.jl) wrapper geometries, complete with CRS information.

## Installation

Simply run `using Pkg; Pkg.add(url = "https://github.com/JuliaGeo/RCallSFBridge.jl")` in your Julia REPL.  Ensure that you have the `sf` library installed in whichever R installation RCall.jl uses.

## Usage
```julia
using RCallSFBridge
```
is all that's needed, then you can use RCall's `rcopy` function or `@rget` macro to get your R data.  Conversion is performed automatically and needs no input from the user.