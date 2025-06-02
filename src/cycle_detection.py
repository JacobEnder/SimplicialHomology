# Function to detect and report all 3-cycles (triangles) in an undirected graph 
# represented by adjacency lists. We use the natural ordering of vertices (assuming they are comparable)
# to ensure each triangle is reported exactly once.

def detect_3_cycles(adj):
    """
    Detect all 3-cycles (triangles) in an undirected graph.

    We use an adjacency-matrix approach: (A^3)_ii gives twice each triangle at vertex i,
    then enumerate triangles by intersecting neighbor sets. For each i<j<k, if edges (i,j), (i,k), (j,k) exist,
    we output (i,j,k).

    Parameters:
    - adj (dict): adjacency list of an undirected graph; {vertex: iterable of neighbors}.

    Returns:
    - List of tuples (v,u,w) with v < u < w, each tuple represents a triangle (cycle of length 3).
    """
    # Map vertices to sorted indices
    vertices = sorted(adj)
    index = {v: i for i, v in enumerate(vertices)}
    n = len(vertices)

    # Build bitset of neighbors for each vertex
    neighbors_bits = [0] * n
    for v in vertices:
        i = index[v]
        bits = 0
        for u in adj[v]:
            if u in index:
                bits |= (1 << index[u])
        neighbors_bits[i] = bits

    triangles = []
    # Enumerate triangles by scanning pairs of neighbors
    for i in range(n):
        # Only consider neighbors j > i to enforce ordering
        jmask = neighbors_bits[i] & ~((1 << (i+1)) - 1)
        while jmask:
            lsb = jmask & -jmask
            j = lsb.bit_length() - 1
            # Common neighbors of i and j
            common = neighbors_bits[i] & neighbors_bits[j]
            # Only k > j to maintain i < j < k
            common &= ~((1 << (j+1)) - 1)
            kmask = common
            while kmask:
                lsb2 = kmask & -kmask
                k = lsb2.bit_length() - 1
                triangles.append((vertices[i], vertices[j], vertices[k]))
                kmask ^= lsb2
            jmask ^= lsb
    return triangles

def detect_4_cycles(adj):
    """
    Detect all 4-cycles (simple cycles of length 4) in an undirected graph.

    The adjacency-matrix trace of A^4 counts 4-cycles (each simple 4-cycle eight times).
    To list them, for each pair of non-adjacent vertices i < j, we find two distinct common neighbors u < w.
    Each such tuple (i, u, j, w) forms a 4-cycle i-u-j-w.

    Parameters:
    - adj (dict): adjacency list of an undirected graph; {vertex: iterable of neighbors}.

    Returns:
    - List of tuples (v, u, v', w) for each 4-cycle, with v < v' and u < w.
    """
    vertices = sorted(adj)
    index = {v: i for i, v in enumerate(vertices)}
    n = len(vertices)
    
    # Build bitset of neighbors for each vertex
    neighbors_bits = [0] * n
    for v in vertices:
        i = index[v]
        bits = 0
        for u in adj[v]:
            if u in index:
                bits |= (1 << index[u])
        neighbors_bits[i] = bits

    cycles = []
    # For each pair i < j without an edge, find two common neighbors
    for i in range(n):
        for j in range(i+1, n):
            # Skip if i-j is an edge
            if (neighbors_bits[i] >> j) & 1:
                continue
            common = neighbors_bits[i] & neighbors_bits[j]
            if not common:
                continue
            # Extract set bits (common neighbors indices)
            common_indices = []
            cm = common
            while cm:
                bit = cm & -cm
                idx = bit.bit_length() - 1
                common_indices.append(idx)
                cm ^= bit
            # For each pair (u, w) of common neighbors (u < w), output cycle (i, u, j, w)
            for x in range(len(common_indices)):
                for y in range(x+1, len(common_indices)):
                    u = common_indices[x]
                    w = common_indices[y]
                    cycles.append((vertices[i], vertices[u], vertices[j], vertices[w]))
    return cycles

def build_simplicial_complex(vertices, adj):
    """
    Build the simplicial complex (X, A) from graph G = (vertices, adj).

    Vertices:
      - vertices: iterable of all vertices in G (must be comparable, e.g., ints or strings).
      - adj: dict mapping each vertex to an iterable of its neighbors.

    Returns:
      - X: a sorted list of vertices of G.
      - A: a set of faces of the simplicial complex. Each face is represented as a tuple:
           * (v,)          for each vertex v
           * (u, v)        for each edge u—v (including newly added diagonals)
           * (u, v, w)     for each triangle face
    """
    # Ensure adjacency lists are sets for fast lookup
    neighbors = {v: set(adj[v]) for v in vertices}
    
    # 1. X: sorted list of vertices
    X = tuple(sorted(vertices))
    
    # Initialize face sets
    A = set()
    
    # 2. Add all 0-faces (vertices)
    for v in X:
        A.add((v,))
    
    # 3. Add all original edges as 1-faces
    #    Keep a set "all_edges" of sorted tuples to track existing edges
    all_edges = set()
    for v in X:
        for u in neighbors[v]:
            if u > v:
                edge = (v, u)
                all_edges.add(edge)
                A.add(edge)
    
    # 4. Detect all original triangles (3-cycles) and add them as 2-faces
    triangles_orig = detect_3_cycles(adj)  # list of (v, u, w) with v < u < w
    for tri in triangles_orig:
        A.add(tri)
    
    # 5. Detect 4-cycles
    four_cycles = detect_4_cycles(adj)  
    # Each 4-cycle is a tuple (v, u, v_prime, w) describing cycle v–u–v_prime–w–v,
    # where (v, v_prime) was not originally an edge.

    for (v, u, v_prime, w) in four_cycles:
        # The new diagonal edge is (v, v_prime) with v < v_prime
        v0, v1 = sorted((v, v_prime))
        diag_edge = (v0, v1)
        
        # If this diagonal isn't already present, add it
        if diag_edge not in all_edges:
            all_edges.add(diag_edge)
            A.add(diag_edge)

        # Now add the two triangles that subdivide the square:
        #   triangle 1: (v, u, v_prime)
        tri1 = tuple(sorted((v, u, v_prime)))
        A.add(tri1)
        
        #   triangle 2: (v, v_prime, w)
        tri2 = tuple(sorted((v, v_prime, w)))
        A.add(tri2)

    return X, A
    
