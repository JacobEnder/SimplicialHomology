function preprocess(adj::Dict{T,Vector{T}}) where T
    # Deep copy to avoid mutating input
    neighbors = Dict(v => sort(copy(adj[v])) for v in keys(adj))
    degrees = Dict(v => length(neighbors[v]) for v in keys(neighbors))
    removed = Set{T}()
    changed = true

    while changed
        changed = false
        verts = sort(collect(keys(neighbors)), by = v -> degrees[v])  # Increasing degree
        for v in verts
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
                    # Remove v
                    for u in Nv
                        if haskey(neighbors, u)
                            deleteat!(neighbors[u], searchsortedfirst(neighbors[u], v))
                        end
                    end
                    delete!(neighbors, v)
                    delete!(degrees, v)
                    push!(removed, v)
                    changed = true
                    break
                end
            end
            if changed
                break
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