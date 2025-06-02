import homology
import time
import json
from cycle_detection import build_simplicial_complex


def homology_from_graph(vertices, adj, mod_2=False):
    X, A = build_simplicial_complex(vertices, adj)

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


def load_graphs(filename="graphs.json"):
    with open(filename, 'r') as f:
        return json.load(f)


def run():
    mod_2 = input("Compute homology mod 2? (y/n): ").strip().lower() == 'y'
    graphs = load_graphs()

    for graph in graphs:
        name = graph.get("name", "Unnamed Graph")
        vertices = graph["vertices"]
        adj = graph["adjacency_list"]

        print(f"Graph: {name}")
        start_time = time.time()
        H0, H1, H2 = homology_from_graph(vertices, adj, mod_2=mod_2)
        elapsed = round(time.time() - start_time, 6)
        print(f"(H0, H1, H2): {H0}, {H1}, {H2}")
        print(f"Time: {elapsed} sec\n")


if __name__ == "__main__":
    run()
