using Base.Threads

# More flexible signature that handles different vector types
function preprocess(adj::Dict{T,V}) where {T, V <: AbstractVector}
    # Convert to consistent types and deep copy to avoid mutating input
    neighbors = Dict{T, Vector{T}}()
    for (k, v) in adj
        neighbors[k] = sort(Vector{T}(v))  # Ensure consistent typing
    end
    
    degrees = Dict(v => length(neighbors[v]) for v in keys(neighbors))
    removed = Set{T}()
    changed = true

    while changed
        changed = false
        verts = sort(collect(keys(neighbors)), by = v -> degrees[v])  # Increasing degree
        
        # Thread-safe removal tracking
        to_remove = Vector{Vector{T}}(undef, nthreads())
        for i in 1:nthreads()
            to_remove[i] = T[]
        end
        
        @threads for i in eachindex(verts)
            tid = threadid()
            v = verts[i]
            if v in removed
                continue
            end
            
            Nv = neighbors[v]
            for w in verts
                if w == v || w in removed || degrees[w] < degrees[v]
                    continue
                end
                Nw = neighbors[w]
                # Subset test Nv ⊆ Nw ∪ {w}
                if is_subset_sorted(Nv, Nw, w)
                    push!(to_remove[tid], v)
                    break
                end
            end
        end
        
        # Process removals sequentially to avoid race conditions
        vertices_to_remove = vcat(to_remove...)
        for v in vertices_to_remove
            if v ∉ removed
                Nv = neighbors[v]
                # Remove v from all its neighbors
                for u in Nv
                    if haskey(neighbors, u)
                        deleteat!(neighbors[u], searchsortedfirst(neighbors[u], v))
                    end
                end
                delete!(neighbors, v)
                delete!(degrees, v)
                push!(removed, v)
                changed = true
            end
        end
    end

    return Set(keys(neighbors)), neighbors
end

# Two-pointer subset check: A ⊆ B ∪ {extra}
function is_subset_sorted(A::Vector{T}, B::Vector{T}, extra::T) where T
    i = j = 1
    while i <= length(A)
        if j <= length(B) && A[i] == B[j]
            i += 1
            j += 1
        elseif A[i] == extra
            i += 1
        elseif j <= length(B) && A[i] > B[j]
            j += 1
        else
            return false
        end
    end
    return true
end