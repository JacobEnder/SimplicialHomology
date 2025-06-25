# Function to detect and report all 3-cycles (triangles) in an undirected graph 
# represented by adjacency lists. We use the natural ordering of vertices (assuming they are comparable)
# to ensure each triangle is reported exactly once.

function detect_3_cycles(adj)
    """
    Detect all 3-cycles (triangles) in an undirected graph.

    We use an adjacency-matrix approach: (A^3)_ii gives twice each triangle at vertex i,
    then enumerate triangles by intersecting neighbor sets. For each i<j<k, if edges (i,j), (i,k), (j,k) exist,
    we output (i,j,k).

    Parameters:
    - adj: adjacency list of an undirected graph; Dict mapping vertex to iterable of neighbors.

    Returns:
    - Array of tuples (v,u,w) with v < u < w, each tuple represents a triangle (cycle of length 3).
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

    triangles = []
    # Enumerate triangles by scanning pairs of neighbors
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

function detect_4_cycles(adj)
    """
    Detect all 4-cycles in an undirected graph.

    The adjacency-matrix trace of A^4 counts 4-cycles (each simple 4-cycle eight times).
    To list them, for each pair of non-adjacent vertices i < j, we find two distinct common neighbors u < w.
    Each such tuple (i, u, j, w) forms a 4-cycle i-u-j-w.

    Parameters:
    - adj: adjacency list of an undirected graph; Dict mapping vertex to iterable of neighbors.

    Returns:
    - Array of tuples (v, u, v', w) for each 4-cycle, with v < v' and u < w.
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

    cycles = []
    # For each pair i < j without an edge, find two common neighbors
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
    
    # Sort vertices
    X = sort(collect(vertices))
    
    # Initialize face sets
    A = Set()
    
    # Add all 0-faces (vertices)
    for v in X
        push!(A, (v,))
    end
    
    # Add all original edges as 1-faces
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
    
    # Detect all original triangles (3-cycles) and add them as 2-faces
    triangles_orig = detect_3_cycles(adj)  # array of (v, u, w) with v < u < w
    for tri in triangles_orig
        push!(A, tri)
    end
    
    # Detect 4-cycles
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

        # Now add the two triangles that subdivide the square.
        #   triangle 1: (v, u, v_prime)
        tri1 = tuple(sort([v, u, v_prime])...)
        push!(A, tri1)
        
        #   triangle 2: (v, v_prime, w)
        tri2 = tuple(sort([v, v_prime, w])...)
        push!(A, tri2)
    end

    return X, A
end