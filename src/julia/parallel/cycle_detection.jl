# Function to detect and report all 3-cycles (triangles) in an undirected graph 
# represented by adjacency lists. We use the natural ordering of vertices (assuming they are comparable)
# to ensure each triangle is reported exactly once.

module CycleDetection

using DataStructures  # for BitSet
using SparseArrays
using Base.Threads

export detect_3_cycles, detect_4_cycles, build_simplicial_complex

function detect_3_cycles(adj)

    vertices = sort(collect(keys(adj)))
    n = length(vertices)
    vertex_to_idx = Dict(v => i for (i, v) in enumerate(vertices))
    
    # Build sparse adjacency matrix
    I = Int[]
    J = Int[]
    
    for v in vertices
        i = vertex_to_idx[v]
        for u in adj[v]
            if haskey(vertex_to_idx, u)
                j = vertex_to_idx[u]
                push!(I, i)
                push!(J, j)
            end
        end
    end
    
    A = sparse(I, J, ones(Int, length(I)), n, n)
    
    # Thread-safe triangle collection
    triangles = Vector{Vector{Tuple{Any,Any,Any}}}(undef, nthreads())
    for i in 1:nthreads()
        triangles[i] = []
    end
    
    @threads for i in 1:n
        tid = threadid()
        for j in (i+1):n
            if A[i, j] > 0  # Edge exists
                # Find common neighbors
                neighbors_i = findall(x -> x > 0, A[i, :])
                neighbors_j = findall(x -> x > 0, A[j, :])
                
                common = intersect(neighbors_i, neighbors_j)
                for k in common
                    if k > j  # Maintain ordering i < j < k
                        push!(triangles[tid], (vertices[i], vertices[j], vertices[k]))
                    end
                end
            end
        end
    end
    
    # Flatten results
    return vcat(triangles...)
end

function detect_4_cycles(adj)
   
    vertices = sort(collect(keys(adj)))
    vertex_to_idx = Dict(v => i for (i, v) in enumerate(vertices))
    n = length(vertices)
    
    # Convert to sets for fast intersection
    adj_sets = Dict(v => Set(adj[v]) for v in vertices)
    
    # Build all wedges (paths of length 2) efficiently with parallelization
    wedges_per_thread = Vector{Vector{Any}}(undef, nthreads())
    for i in 1:nthreads()
        wedges_per_thread[i] = []
    end
    
    @threads for i in eachindex(vertices)
        tid = threadid()
        v = vertices[i]
        neighbors_v = collect(adj_sets[v])
        # Generate all pairs of neighbors (forming wedges centered at v)
        for i in 1:length(neighbors_v)
            for j in (i+1):length(neighbors_v)
                u, w = neighbors_v[i], neighbors_v[j]
                # Store wedge as (endpoint1, center, endpoint2) with endpoint1 < endpoint2
                if u < w
                    push!(wedges_per_thread[tid], (u, v, w))
                else
                    push!(wedges_per_thread[tid], (w, v, u))
                end
            end
        end
    end
    
    wedges = vcat(wedges_per_thread...)
    
    # Group wedges by their endpoints
    wedge_groups = Dict()
    for (u, v, w) in wedges
        key = (u, w)
        if !haskey(wedge_groups, key)
            wedge_groups[key] = []
        end
        push!(wedge_groups[key], v)
    end
    
    # For each pair of endpoints that appear in multiple wedges, we have 4-cycles
    cycles = []
    for ((u, w), centers) in wedge_groups
        if length(centers) >= 2
            # Each pair of centers forms a 4-cycle with endpoints u, w
            for i in 1:length(centers)
                for j in (i+1):length(centers)
                    v1, v2 = centers[i], centers[j]
                    # Ensure proper ordering for the 4-cycle representation
                    if v1 < v2
                        push!(cycles, (u, v1, w, v2))
                    else
                        push!(cycles, (u, v2, w, v1))
                    end
                end
            end
        end
    end
    
    return cycles
end



function build_simplicial_complex(vertices, adj)
    """
    Build the simplicial complex (X, A) from graph G = (vertices, adj).

    Vertices:
      - vertices: iterable of all vertices in G (must be comparable, e.g., ints or strings).
      - adj: dict mapping each vertex to an iterable of its neighbors.

    Returns:
      - X: a sorted array of vertices of G.
      - A: a set of faces of the simplicial complex. Each face is represented as a tuple.
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
    #    Keep a set "all_edges" of sorted tuples to track existing edges
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
    triangles_orig = detect_3_cycles(adj)  # array of (v, u, w) with v < u < w
    for tri in triangles_orig
        push!(A, tri)
    end
    
    # 5. Detect 4-cycles
    four_cycles = detect_4_cycles(adj)  
    # Each 4-cycle is a tuple (v, u, v_prime, w), where (v, v_prime) was not originally an edge.

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
        #   triangle 1: (v, u, v_prime)
        tri1 = tuple(sort([v, u, v_prime])...)
        push!(A, tri1)
        
        #   triangle 2: (v, v_prime, w)
        tri2 = tuple(sort([v, v_prime, w])...)
        push!(A, tri2)
    end

    return X, A
end

end