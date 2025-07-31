include("homology.jl")

# Little helper function for sorting, just to reduce bulk.
function sort_neighborhoods!(adj)
    for u in keys(adj)
        sort!(adj[u])
    end
end

function is_subset(adj, v, w)
    # Check if N(v) ⊆ N(w) using a two-pointer approach for speed.
    A, B = adj[v], adj[w]
    i = j = 1
    while i <= length(A) && j <= length(B)
        if A[i] == B[j]
            i += 1
            j += 1
        elseif A[i] > B[j]
            j += 1
        else
            return false
        end
    end
    return i > length(A)
end

function remove_vertex!(adj, v)
    # Remove v from neighbors, then update adjacencies
    for u in adj[v]
        # adj[u] is sorted, so use binary search to find and delete v
        idx = searchsortedfirst(adj[u], v)
        if idx <= length(adj[u]) && adj[u][idx] == v
            deleteat!(adj[u], idx)
        end
    end
    delete!(adj, v)
end

function preprocess(adj)
    # Deep copy to preserve original input
    adj_copy = Dict(v => copy(neighbors) for (v, neighbors) in adj)

    # Convert adjacency lists to sets for fast subset testing
    neighbors = Dict(v => Set(adj_copy[v]) for v in keys(adj_copy))
    removed = Set()

    changed = true
    while changed
        changed = false
        vertices_to_check = collect(keys(neighbors))
        for v in vertices_to_check
            if v in removed
                continue
            end
            Nv = neighbors[v]
            for w in keys(neighbors)
                if w == v || w in removed
                    continue
                end
                Nw = neighbors[w]
                if length(Nw) < length(Nv)
                    continue
                end
                # Allow domination if N(v) ⊆ N(w) ∪ {w} to count self-loops
                if Nv ⊆ (Nw ∪ Set([w]))
                    # Remove v and its edges
                    for u in Nv
                        if haskey(neighbors, u)
                            delete!(neighbors[u], v)
                        end
                    end
                    push!(removed, v)
                    delete!(neighbors, v)
                    changed = true
                    break
                end
            end
            if changed
                break
            end
        end
    end

    # Convert sets back to sorted arrays for adjacency list format
    reduced_adj = Dict(v => sort(collect(neighbors[v])) for v in keys(neighbors))
    return Set(keys(reduced_adj)), reduced_adj
end