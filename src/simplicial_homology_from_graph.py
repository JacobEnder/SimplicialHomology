import homology
import time
import json
import os
from cycle_detection import build_simplicial_complex


# Take our graph G, build a simplicial complex (X, A) over it, and calculate the homology of (X,A)
# over the user's choice of Q or Z/2

def homology_from_graph(vertices, adj, mod_2=False):

    # Build a simplicial complex associated to G
    X, A = build_simplicial_complex(vertices, adj)

    # Two different fields of coefficients
    if not mod_2:
        return (
            homology.homology(0, A),
            homology.homology(1, A),
            homology.homology(2, A)
        )
    else:
        return (
            homology.homology(0, A, mod_2=True),
            homology.homology(1, A, mod_2=True),
            homology.homology(2, A, mod_2=True)
        )

# Load the JSON file containing all our graphs

def load_graphs(filename="graphs.json"):

    base_dir = os.path.dirname(os.path.abspath(__file__))
    path = os.path.join(base_dir, '..', 'data', filename) # Graphs are stored in /data/graphs.json by default

    with open(path, 'r') as f:
        return json.load(f)


def run():

    # Field selection
    mod_2 = input("Compute homology over Q or Z/2? (q/2): ").strip().lower() == '2'
    graphs = load_graphs()

    # Pull all the graphs from /data/graphs.json, calculate their homology and benchmark the times
    for graph in graphs:
        name = graph.get("name", "Unnamed Graph")
        vertices = graph["vertices"]
        adj = graph["adjacency_list"]

        print(f"Graph: {name}")
        start_time = time.time()
        H0, H1, H2 = homology_from_graph(vertices, adj, mod_2=mod_2)
        elapsed = round(time.time() - start_time, 8)
        print(f"(H0, H1, H2): {H0}, {H1}, {H2}")
        print(f"Time: {elapsed} sec\n")


if __name__ == "__main__":
    run()
