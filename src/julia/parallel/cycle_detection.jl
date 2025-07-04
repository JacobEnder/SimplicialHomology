# Multithreaded cycle detection functions

function detect_3_cycles(adj)
    """
    Detect all 3-cycles (triangles) in an undirected graph using multithreading.
    """
    # Map vertices to sorted indices
    vertices = sort(collect(keys(adj)))
    index = Dict(v => i for (i, v) in enumerate(vertices))
    n = length(vertices)

    # Build BitVector of neighbors for each vertex
    neighbors_bits = [falses(n) for _ in 1:n]
    for v in vertices
        i = index[v]
        for u in adj[v]
            if haskey(index, u)
                neighbors_bits[i][index[u]] = true
            end
        end
    end

    # Use parallel processing for larger graphs
    if n > 100 && Threads.nthreads() > 1
        # Parallel version
        triangles_per_thread = [Vector{Tuple{eltype(vertices), eltype(vertices), eltype(vertices)}}() for _ in 1:Threads.nthreads()]
        
        Threads.@threads for i in 1:n
            tid = Threads.threadid()
            
            # Only consider neighbors j > i to enforce ordering
            jmask = copy(neighbors_bits[i])
            for idx in 1:i
                jmask[idx] = false
            end
            
            for j in (i+1):n
                if !jmask[j]
                    continue
                end
                
                # Common neighbors of i and j
                common = neighbors_bits[i] .& neighbors_bits[j]
                # Only k > j to maintain i < j < k
                for idx in 1:j
                    common[idx] = false
                end
                
                for k in (j+1):n
                    if common[k]
                        push!(triangles_per_thread[tid], (vertices[i], vertices[j], vertices[k]))
                    end
                end
            end
        end
        
        # Combine results
        triangles = Vector{Tuple{eltype(vertices), eltype(vertices), eltype(vertices)}}()
        for thread_results in triangles_per_thread
            append!(triangles, thread_results)
        end
        
        return triangles
    else
        # Sequential version for smaller graphs
        triangles = []
        for i in 1:n
            # Only consider neighbors j > i to enforce ordering
            jmask = copy(neighbors_bits[i])
            for idx in 1:i
                jmask[idx] = false
            end
            
            for j in (i+1):n
                if !jmask[j]
                    continue
                end
                
                # Common neighbors of i and j
                common = neighbors_bits[i] .& neighbors_bits[j]
                # Only k > j to maintain i < j < k
                for idx in 1:j
                    common[idx] = false
                end
                
                for k in (j+1):n
                    if common[k]
                        push!(triangles, (vertices[i], vertices[j], vertices[k]))
                    end
                end
            end
        end
        return triangles
    end
end

function detect_4_cycles(adj)
    """
    Detect all 4-cycles in an undirected graph using multithreading.
    """
    vertices = sort(collect(keys(adj)))
    index = Dict(v => i for (i, v) in enumerate(vertices))
    n = length(vertices)
    
    # Build BitVector of neighbors for each vertex
    neighbors_bits = [falses(n) for _ in 1:n]
    for v in vertices
        i = index[v]
        for u in adj[v]
            if haskey(index, u)
                neighbors_bits[i][index[u]] = true
            end
        end
    end

    # Use parallel processing for larger graphs
    if n > 50 && Threads.nthreads() > 1
        # Parallel version
        cycles_per_thread = [Vector{Tuple{eltype(vertices), eltype(vertices), eltype(vertices), eltype(vertices)}}() for _ in 1:Threads.nthreads()]
        
        Threads.@threads for i in 1:n
            tid = Threads.threadid()
            
            for j in (i+1):n
                # Skip if i-j is an edge
                if neighbors_bits[i][j]
                    continue
                end
                
                common = neighbors_bits[i] .& neighbors_bits[j]
                if !any(common)
                    continue
                end
                
                # Extract common neighbor indices
                common_indices = findall(common)
                
                # For each pair (u, w) of common neighbors (u < w), output cycle (i, u, j, w)
                for x in 1:length(common_indices)
                    for y in (x+1):length(common_indices)
                        u = common_indices[x]
                        w = common_indices[y]
                        push!(cycles_per_thread[tid], (vertices[i], vertices[u], vertices[j], vertices[w]))
                    end
                end
            end
        end
        
        # Combine results
        cycles = Vector{Tuple{eltype(vertices), eltype(vertices), eltype(vertices), eltype(vertices)}}()
        for thread_results in cycles_per_thread
            append!(cycles, thread_results)
        end
        
        return cycles
    else
        # Sequential version for smaller graphs
        cycles = []
        for i in 1:n
            for j in (i+1):n
                # Skip if i-j is an edge
                if neighbors_bits[i][j]
                    continue
                end
                
                common = neighbors_bits[i] .& neighbors_bits[j]
                if !any(common)
                    continue
                end
                
                # Extract common neighbor indices
                common_indices = findall(common)
                
                # For each pair (u, w) of common neighbors (u < w), output cycle (i, u, j, w)
                for x in 1:length(common_indices)
                    for y in (x+1):length(common_indices)
                        u = common_indices[x]
                        w = common_indices[y]
                        push!(cycles, (vertices[i], vertices[u], vertices[j], vertices[w]))
                    end
                end
            end
        end
        return cycles
    end
end

function build_simplicial_complex(vertices, adj)
    """
    Build the simplicial complex (X, A) from graph G = (vertices, adj) with multithreading.
    """
    # Ensure adjacency lists are sets for fast lookup
    neighbors = Dict(v => Set(adj[v]) for v in vertices)
    
    # 1. X: sorted array of vertices
    X = sort(collect(vertices))
    
    # Initialize face sets
    A = Set()
    
    # 2. Add all 0-faces (vertices)
    for v in X
        push!(A, (v,))
    end
    
    # 3. Add all original edges as 1-faces
    all_edges = Set()
    for v in X
        for u in neighbors[v]
            if u > v
                edge = (v, u)
                push!(all_edges, edge)
                push!(A, edge)
            end
        end
    end
    
    # 4. Detect all original triangles (3-cycles) and add them as 2-faces
    triangles_orig = detect_3_cycles(adj)  # Multithreaded
    for tri in triangles_orig
        push!(A, tri)
    end
    
    # 5. Detect 4-cycles (multithreaded)
    four_cycles = detect_4_cycles(adj)  

    # Process 4-cycles to add diagonal edges and triangles
    # Use locks for thread-safe set operations when there are many cycles
    if length(four_cycles) > 100 && Threads.nthreads() > 1
        lock = ReentrantLock()
        
        Threads.@threads for cycle in four_cycles
            v, u, v_prime, w = cycle
            
            # The new diagonal edge is (v, v_prime) with v < v_prime
            v0, v1 = v < v_prime ? (v, v_prime) : (v_prime, v)
            diag_edge = (v0, v1)
            
            # Thread-safe operations
            lock() do
                # If this diagonal isn't already present, add it
                if !(diag_edge in all_edges)
                    push!(all_edges, diag_edge)
                    push!(A, diag_edge)
                end

                # Add the two triangles that subdivide the square:
                tri1 = tuple(sort([v, u, v_prime])...)
                push!(A, tri1)
                
                tri2 = tuple(sort([v, v_prime, w])...)
                push!(A, tri2)
            end
        end
    else
        # Sequential processing for smaller numbers of cycles
        for (v, u, v_prime, w) in four_cycles
            # The new diagonal edge is (v, v_prime) with v < v_prime
            v0, v1 = v < v_prime ? (v, v_prime) : (v_prime, v)
            diag_edge = (v0, v1)
            
            # If this diagonal isn't already present, add it
            if !(diag_edge in all_edges)
                push!(all_edges, diag_edge)
                push!(A, diag_edge)
            end

            # Now add the two triangles that subdivide the square:
            tri1 = tuple(sort([v, u, v_prime])...)
            push!(A, tri1)
            
            tri2 = tuple(sort([v, v_prime, w])...)
            push!(A, tri2)
        end
    end

    return X, A
end