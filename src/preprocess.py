import homology
import os
import copy

def sort_neighborhoods(adj):
    for u in adj:
        adj[u].sort()

def is_subset(adj, v, w):
    # Check if N(v) ⊆ N(w) using two-pointer
    A, B = adj[v], adj[w]
    i = j = 0
    while i < len(A) and j < len(B):
        if A[i] == B[j]:
            i += 1
            j += 1
        elif A[i] > B[j]:
            j += 1
        else:
            return False
    return i == len(A)

def remove_vertex(adj, v):
    # Remove v from neighbors, then delete its list
    for u in adj[v]:
        # adj[u] is sorted; binary search for v and pop
        lo, hi = 0, len(adj[u])
        while lo < hi:
            mid = (lo+hi)//2
            if adj[u][mid] < v:
                lo = mid + 1
            else:
                hi = mid
        if lo < len(adj[u]) and adj[u][lo] == v:
            adj[u].pop(lo)
    del adj[v]

def preprocess(adj):
    # Deep copy to preserve original input
    adj = copy.deepcopy(adj)

    # Convert adjacency lists to sets for fast subset testing
    neighbors = {v: set(adj[v]) for v in adj}
    removed = set()

    changed = True
    while changed:
        changed = False
        for v in list(neighbors.keys()):
            if v in removed:
                continue
            Nv = neighbors[v]
            for w in neighbors:
                if w == v or w in removed:
                    continue
                Nw = neighbors[w]
                if len(Nw) < len(Nv):
                    continue
                #Allow domination if N(v) ⊆ N(w) ∪ {w} to count self-loops
                if Nv <= (Nw | {w}):
                    # Remove v and its edges
                    for u in Nv:
                        neighbors[u].discard(v)
                    removed.add(v)
                    del neighbors[v]
                    changed = True
                    break
            if changed:
                break

    # Convert sets back to sorted lists for adjacency list format
    reduced_adj = {v: sorted(list(neighbors[v])) for v in neighbors}
    return set(reduced_adj.keys()), reduced_adj

