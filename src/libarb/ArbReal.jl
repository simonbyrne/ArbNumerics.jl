"""
from ArbReal docs:

An arb_t represents a ball over the real numbers, that is, an interval [m±r]≡[m−r,m+r]
where the midpoint m and the radius r are (extended) real numbers and r is nonnegative (possibly infinite).
The result of an (approximate) operation done on arb_t variables is a ball which contains
the result of the (mathematically exact) operation applied to any choice of points in the input balls.
In general, the output ball is not the smallest possible.

The precision parameter passed to each function roughly indicates the precision to which calculations
on the midpoint are carried out (operations on the radius are always done using a fixed, small precision.)
""" ArbReal

# ArbReal structs hold balls given as midpoint, radius

mutable struct ArbReal{P} <: Real     # P is the precision in bits
                    #      midpoint
    mid_exp::Int    # fmpz         exponent of 2 (2^exp)
    mid_size::UInt  # mp_size_t    nwords and sign (lsb holds sign of significand)
    mid_d1::UInt    # significand  unsigned, immediate value or the initial span
    mid_d2::UInt    #   (d1, d2)   the final part indicating the significand, or 0
                    #      radius
    rad_exp::Int    # fmpz       exponent of 2 (2^exp)
    rad_man::UInt   # mp_limb_t  radius, unsigned by definition

    function ArbReal{P}() where {P}
        z = new{P}()
        ccall(@libarb(arb_init), Cvoid, (Ref{ArbReal},), z)
        finalizer(arb_clear, z)
        return z
    end
end

arb_clear(x::ArbReal{P}) where {P} = ccall(@libarb(arb_clear), Cvoid, (Ref{ArbReal},), x)

ArbReal{P}(x::ArbReal{P}) where {P} = x
ArbReal(x::ArbReal{P}) where {P} = x

ArbReal{P}(x::Missing) where {P} = missing
ArbReal(x::Missing) = missing

@inline sign_bit(x::ArbReal{P}) where {P} = isodd(x.mid_size)

ArbReal(x, prec::Int) = prec>=MINIMUM_PRECISION ? ArbReal{workingbits(prec)}(x) : throw(DomainError("bit precision ($prec) is too low"))


swap(x::ArbReal{P}, y::ArbReal{P}) where {P} = ccall(@libarb(arb_swap), Cvoid, (Ref{ArbReal}, Ref{ArbReal}), x, y)

function copy(x::ArbReal{P}) where {P}
    z = ArbReal{P}()
    ccall(@libarb(arb_set), Cvoid, (Ref{ArbReal}, Ref{ArbReal}), z, x)
    return z
end


function ArbReal{P}(x::Int64) where {P}
    z = ArbReal{P}()
    ccall(@libarb(arb_set_si), Cvoid, (Ref{ArbReal}, Clong), z, x)
    return z
end
ArbReal{P}(x::T) where {P, T<:Union{Int8, Int16, Int32}} = ArbReal{P}(Int64(x))

function ArbReal{P}(x::UInt64) where {P}
    z = ArbReal{P}()
    ccall(@libarb(arb_set_ui), Cvoid, (Ref{ArbReal}, Culong), z, x)
    return z
end
ArbReal{P}(x::T) where {P, T<:Union{UInt8, UInt16, UInt32}} = ArbReal{P}(UInt64(x))

function ArbReal{P}(x::Float64) where {P}
    z = ArbReal{P}()
    ccall(@libarb(arb_set_d), Cvoid, (Ref{ArbReal}, Cdouble), z, x)
    return z
end
ArbReal{P}(x::T) where {P, T<:Union{Float16, Float32}} = ArbReal{P}(Float64(x))

function ArbReal{P}(x::BigFloat) where {P}
    z = ArbReal{P}()
    ccall(@libarb(arb_set_interval_mpfr), Cvoid, (Ref{ArbReal}, Ref{BigFloat}, Ref{BigFloat}, Clong), z, x, x, P)
    return z
end
ArbReal{P}(x::BigInt) where {P} = ArbReal{P}(BigFloat(x))
ArbReal{P}(x::Rational{T}) where {P, T<:Signed} = ArbReal{P}(BigFloat(x))


function ArbReal{P}(x::Irrational{S}) where {P,S}
    y = ArbFloat{P}(x)
    z = ArbReal{P}(y)
    return z
end

function ArbReal{P}(x::ArbFloat{P}) where {P}
    z = ArbReal{P}()
    ccall(@libarb(arb_set_arf), Cvoid, (Ref{ArbReal}, Ref{ArbFloat}), z, x)
    return z
end

function midpoint(x::ArbReal{P}) where {P}
    z = ArbReal{P}()
    ccall(@libarb(arb_get_mid_arb), Cvoid, (Ref{ArbReal}, Ref{ArbReal}), z, x)
    return z
end

function radius(x::ArbReal{P}) where {P}
    z = ArbReal{P}()
    ccall(@libarb(arb_get_rad_arb), Cvoid, (Ref{ArbReal}, Ref{ArbReal}), z, x)
    return z
end

function midpoint_byref(x::ArbReal{P}) where {P}
    w = ArbReal{P}()
    ccall(@libarb(arb_get_mid_arb), Cvoid, (Ref{ArbReal}, Ref{ArbReal}), w, x)
    z = ArbFloat{P}(w)
    return z
end

function radius_byref(x::ArbReal{P}) where {P}
    w = ArbReal{P}()
    ccall(@libarb(arb_get_rad_arb), Cvoid, (Ref{ArbReal}, Ref{ArbReal}), w, x)
    z = ArbFloat{P}(w)
    return z
end

midpoint(x::ArbReal{P}, ::Type{ArbFloat{P}}) where {P} = midpoint_byref(x)
radius(x::ArbReal{P}, ::Type{Mag}) where {P} = radius_byref(x)

function radius(x::ArbReal{P}, ::Type{ArbFloat{P}}) where {P}
    z = ArbFloat{P}()
    mag = radius_byref(x)
    ccall(@libarb(arf_set_mag), Cvoid, (Ref{ArbFloat}, Ref{Mag}), z, mag)
    return z
end
