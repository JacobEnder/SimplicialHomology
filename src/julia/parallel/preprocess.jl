include("homology.jl")

function sort_neighborhoods!(adj)
    # Parallelize sorting for large graphs
    vertices = collect(keys(adj))
    
    if length(vertices) > 50 && Threads.nthreads() > 1
        Threads.@threads for u in vertices
            sort!(adj[u])
        end
    else
        for u in vertices
            sort!(adj[u])
        end
    end
end

function is_subset(adj, v, w)
    # Check if N(v) ⊆ N(w) using two-pointer
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
    # Remove v from neighbors, then delete its list
    for u in adj[v]
        # adj[u] is sorted; binary search for v and delete
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
        
        # Use multithreading for domination checking on larger graphs
        if length(vertices_to_check) > 100 && Threads.nthreads() > 1
            # Thread-safe domination detection
            dominated_vertices = Vector{Any}()
            lock = ReentrantLock()
            
            # Parallel check for dominated vertices
            Threads.@threads for v in vertices_to_check
                if v in removed
                    continue
                end
                
                Nv = neighbors[v]
                found_dominator = false
                
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
                        found_dominator = true
                        break
                    end
                end
                
                if found_dominator
                    lock() do
                        push!(dominated_vertices, v)
                    end
                end
            end
            
            # Remove dominated vertices sequentially to avoid race conditions
            for v in dominated_vertices
                if v ∉ removed  # Double-check since we might have removed it already
                    Nv = neighbors[v]
                    # Remove v and its edges
                    for u in Nv
                        if haskey(neighbors, u)
                            delete!(neighbors[u], v)
                        end
                    end
                    push!(removed, v)
                    delete!(neighbors, v)
                    changed = true
                end
            end
        else
            # Sequential version for smaller graphs
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
    end

    # Convert sets back to sorted arrays for adjacency list format
    # Parallelize this conversion for large graphs
    vertices = collect(keys(neighbors))
    
    if length(vertices) > 50 && Threads.nthreads() > 1
        reduced_adj = Dict{eltype(vertices), Vector{eltype(vertices)}}()
        lock = ReentrantLock()
        
        Threads.@threads for v in vertices
            sorted_neighbors = sort(collect(neighbors[v]))
            lock() do
                reduced_adj[v] = sorted_neighbors
            end
        end
    else
        reduced_adj = Dict(v => sort(collect(neighbors[v])) for v in vertices)
    end
    
    return Set(keys(reduced_adj)), reduced_adj
end