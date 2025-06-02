# Function to detect and report all 3-cycles (triangles) in an undirected graph 
# represented by adjacency lists. We use the natural ordering of vertices (assuming they are comparable)
# to ensure each triangle is reported exactly once.

def detect_3_cycles(adj):
    """
    Detect and report 3-cycles (triangles) in a graph.

    Parameters:
    - adj: dict
        A dictionary representing the adjacency list of an undirected graph.
        Keys are vertices (comparable: e.g., integers or strings), and values 
        are iterables of neighboring vertices.
    
    Returns:
    - triangles: list of tuples
        A list of tuples (v, u, w) representing each 3-cycle found, 
        with v < u < w in natural order.
    """
    # Ensure adjacency lists are sets for O(1) membership check
    neighbors = {v: set(adj[v]) for v in adj}
    triangles = []

    # Iterate through vertices in sorted (natural) order
    for v in sorted(neighbors):
        Nv = neighbors[v]  # Neighbors of v
        
        # For each pair (u, w) in Nv × Nv, enforce ordering v < u < w
        for u in Nv:
            if u <= v:
                continue
            for w in Nv:
                if w <= u:
                    continue
                # Check if u and w are directly connected
                if w in neighbors[u]:
                    # Report triangle (v, u, w)
                    triangles.append((v, u, w))
        
        # Discard v (remove it so it won't be considered again)
        del neighbors[v]

    return triangles

def detect_4_cycles(adj):
    """
    Detect and report 4-cycles in a graph.

    Parameters:
    - adj: dict
        A dictionary representing the adjacency list of an undirected graph.
        Keys are vertices (comparable: e.g., integers or strings), and values 
        are iterables of neighboring vertices.
    
    Returns:
    - cycles: list of tuples
        A list of tuples (v, u, v', w) representing each 4-cycle found,
        corresponding to the cycle v - u - v' - w - v. Each 4-cycle is reported once.
    """
    # Convert adjacency lists into sets for O(1) neighbor checks
    neighbors = {v: set(adj[v]) for v in adj}
    seen = set()   # to record which 4-vertex sets we've already reported
    cycles = []

    # Sort vertices to enforce an order
    vertices = sorted(neighbors)

    # Look at every unordered pair (v, v') with v < v' and no edge between them
    for i in range(len(vertices)):
        v = vertices[i]
        for j in range(i+1, len(vertices)):
            v_prime = vertices[j]
            if v_prime in neighbors[v]:
                continue  # skip if there's an edge v--v'

            # Find common neighbors of v and v'
            common = neighbors[v].intersection(neighbors[v_prime])
            # If fewer than 2 common neighbors, we can't form a 4-cycle this way
            if len(common) < 2:
                continue

            # Sort common neighbors so we can pick pairs (u, w) with u < w
            sorted_common = sorted(common)
            for x in range(len(sorted_common)):
                u = sorted_common[x]
                for y in range(x+1, len(sorted_common)):
                    w = sorted_common[y]
                    # Now {v, u, v', w} is a candidate 4-cycle
                    cycle_set = frozenset({v, u, v_prime, w})
                    if cycle_set not in seen:
                        seen.add(cycle_set)
                        # We append it in the order v - u - v' - w
                        cycles.append((v, u, v_prime, w))

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


# Example usage:
if __name__ == "__main__":
    vertices = [1, 2, 3, 4]
    adj = {
       1: [2,4],
       2: [1,3],
       3: [2,4],
       4: [1,3]
    }

    X, A = build_simplicial_complex(vertices, adj)

    print("Vertices (X):")
    print(X)
    print("\nFaces (A):")
    for face in sorted(A, key=lambda f: (len(f), f)):
        print(face)
     
