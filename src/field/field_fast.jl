### FUNCTIONS TO UPDATE ELECTRIC FIELDS ###

function update_E_total!(E_total, kEs) # test timing
    @inbounds @fastmath for q ∈ 1:3
        E_q_re = zero(eltype(E_total))
        E_q_im = zero(eltype(E_total))
        for k ∈ 1:6
            E_q_re += kEs.re[k,q]
            E_q_im += kEs.im[k,q]
        end
        E_total.re[q] = E_q_re
        E_total.im[q] = E_q_im
    end
    return nothing
end

function update_rsquared2!(r2, r)
    r2[1,1] = r[2]^2 + r[3]^2
    r2[1,2] = r[1]^2 + r[3]^2
    r2[1,3] = r[1]^2 + r[2]^2
    return nothing
end

function update_rs!(rs, r, denom)
    update_rsquared2!(rs, r)
    @turbo for k ∈ 1:3
        rs[2,k] = sqrt(exp(-rs[1,k]/denom)) # sqrt from √s
    end
    return nothing
end

"""
    E_kq: array of dims k × q, with each row representing the E field along each k direction
    (would this be better as q × k)?
"""
function update_E_kq!(E_kq, as, ϵs)
    @turbo for q ∈ 1:3
        # iterate over k directions 
        for k ∈ axes(as,1)
            E_kq_re = zero(eltype(E_kq))
            E_kq_im = zero(eltype(E_kq))
            # iterate over frequencies
            for f ∈ axes(as,2)
                a_re = as.re[k,f]
                a_im = as.im[k,f]
                ϵ_re = ϵs.re[k,f,q]
                ϵ_im = -ϵs.im[k,f,q] # take conjugate 
                a = ϵ_re * a_re - ϵ_im * a_im
                b = ϵ_re * a_im + ϵ_im * a_re
                E_kq_re += a
                E_kq_im += b
            end
            E_kq.re[k,q] = E_kq_re
            E_kq.im[k,q] = E_kq_im
        end
    end
    return nothing
end

function update_ϕs!(ϕs, ωs, r, t)
    @inbounds @fastmath for i ∈ 1:3
        ϕs[1,i] = -r[i] # -k ⋅ r
    end
    @inbounds @fastmath for i ∈ eachindex(ωs)
        ϕs[1,i+3] = ωs[i] * t # ω * t
    end
    @turbo for i ∈ axes(ϕs,2)
        ϕs[2,i], ϕs[3,i] = sincos(ϕs[1,i])
    end
    return nothing
end

function update_as!(ϕs, as, rs)
    @turbo for k ∈ 1:3
        # kr factor
        re_k = ϕs[3,k] * rs[2,k] # check speed of this function
        im_k = ϕs[2,k] * rs[2,k]
        
        for f ∈ axes(as,2)
            # ωt factor
            re_f = ϕs[3,3+f]
            im_f = ϕs[2,3+f]

            a = re_k * re_f - im_k * im_f
            b = re_k * im_f + im_k * re_f

            as.re[k,f] = a
            as.im[k,f] = b

            # include a negative phase for the -k vectors
            c = re_k * re_f + im_k * im_f
            d = re_k * im_f - im_k * re_f
            
            as.re[k+3,f] = c
            as.im[k+3,f] = d
        end
    end
    return nothing
end
export update_as!

function update_fields_fast!(p, r, t)
    
    # update saturation ratios
    update_rs!(p.rs, r, p.denom)
    
    # update phases
    update_ϕs!(p.ϕs, p.ωs, r, t)
    
    # update amplitudes
    update_as!(p.ϕs, p.as, p.rs)
    
    # update kEs
    update_E_kq!(p.kEs, p.as, p.ϵs_scaled)

    # update total E
    update_E_total!(p.E_total, p.kEs)
    
    return nothing
end
export update_fields_fast!