import networkx as nx
import matplotlib.pyplot as plt
from matplotlib.backend_bases import MouseButton
from matplotlib.widgets import TextBox
import json
import os

class GraphDrawer:
    def __init__(self):
        self.G = nx.Graph()
        self.pos = {}
        self.node_labels = {}
        self.next_node_id = 0
        self.fig, self.ax = plt.subplots()
        self.fig.subplots_adjust(left=0.05, right=0.95, top=0.9, bottom=0.15)
        self.cid_click = self.fig.canvas.mpl_connect('button_press_event', self.on_click)
        self.cid_key = self.fig.canvas.mpl_connect('key_press_event', self.on_key)
        self.selected_nodes = []
        self.label_input_mode = False
        self.waiting_for_new_label = False
        self.delete_mode = None  # 'node' or 'edge'
        self.new_label_box = None
        self.new_node_pos = None
        self.editing_node = None
        self.init_text_box()

    def init_text_box(self):
        axbox = self.fig.add_axes([0.35, 0.02, 0.3, 0.05])
        self.new_label_box = TextBox(axbox, 'New Node Label: ')
        self.new_label_box.on_submit(self.submit_new_label)
        self.new_label_box.ax.set_visible(False)  # Hide initially

    def submit_new_label(self, label):
        label = label.strip()
        if label == '':
            # Ignore empty labels; cancel new node or rename
            self.cancel_label_input()
            return

        if self.waiting_for_new_label:
            # Add new node with this label
            node_id = self.next_node_id
            self.G.add_node(node_id)
            self.pos[node_id] = self.new_node_pos
            self.node_labels[node_id] = label
            self.next_node_id += 1
            self.waiting_for_new_label = False
            self.new_node_pos = None
        elif self.label_input_mode and self.editing_node is not None:
            # Rename existing node
            self.node_labels[self.editing_node] = label
            self.editing_node = None
            self.label_input_mode = False

        self.new_label_box.set_val('')
        self.new_label_box.ax.set_visible(False)
        self.fig.canvas.draw_idle()
        self.redraw()

    def cancel_label_input(self):
        # Called if user submits empty label
        self.waiting_for_new_label = False
        self.label_input_mode = False
        self.editing_node = None
        self.new_node_pos = None
        self.new_label_box.set_val('')
        self.new_label_box.ax.set_visible(False)
        self.fig.canvas.draw_idle()
        self.redraw()

    def on_click(self, event):
        if event.inaxes != self.ax:
            return

        if self.delete_mode == 'node':
            node = self.get_node_at(event.xdata, event.ydata)
            if node is not None:
                self.G.remove_node(node)
                self.pos.pop(node, None)
                self.node_labels.pop(node, None)
                self.next_node_id = max(self.G.nodes, default=-1) + 1
                self.delete_mode = None
                self.redraw()
            return
        elif self.delete_mode == 'edge':
            node = self.get_node_at(event.xdata, event.ydata)
            if node is not None:
                self.selected_nodes.append(node)
                if len(self.selected_nodes) == 2:
                    if self.G.has_edge(*self.selected_nodes):
                        self.G.remove_edge(*self.selected_nodes)
                    self.selected_nodes = []
                    self.delete_mode = None
                    self.redraw()
            return

        if event.button is MouseButton.LEFT:
            if not self.label_input_mode and not self.waiting_for_new_label:
                # Begin new node creation process
                self.new_node_pos = (event.xdata, event.ydata)
                self.waiting_for_new_label = True
                self.new_label_box.ax.set_visible(True)
                self.new_label_box.set_val('')
                self.fig.canvas.draw_idle()
                try:
                    self.new_label_box.textbox.set_focus()
                except Exception:
                    pass
            elif self.label_input_mode:
                # If in label editing mode, clicking a node opens rename textbox
                node = self.get_node_at(event.xdata, event.ydata)
                if node is not None:
                    self.editing_node = node
                    self.new_label_box.ax.set_visible(True)
                    self.new_label_box.set_val(self.node_labels.get(node, ''))
                    self.fig.canvas.draw_idle()
                    try:
                        self.new_label_box.textbox.set_focus()
                    except Exception:
                        pass
        elif event.button is MouseButton.RIGHT:
            node = self.get_node_at(event.xdata, event.ydata)
            if node is not None:
                self.selected_nodes.append(node)
                if len(self.selected_nodes) == 2:
                    self.G.add_edge(*self.selected_nodes)
                    self.selected_nodes = []
            self.redraw()

    def on_key(self, event):
        if event.key == 'v':  # Save shortcut
            name = input("Enter a name for the graph: ")
            self.save_to_json("graphs.json", name)
        elif event.key == 'l':
            self.label_input_mode = True
            print("Label input mode: click a node to rename")
        elif event.key == 'd':
            self.delete_mode = 'node'
            print("Delete mode: click a node to delete")
        elif event.key == 'e':
            self.delete_mode = 'edge'
            self.selected_nodes = []
            print("Delete edge mode: right-click two nodes to remove their edge")

    def get_node_at(self, x, y, tolerance=0.05):
        for node, (nx_, ny_) in self.pos.items():
            if abs(nx_ - x) < tolerance and abs(ny_ - y) < tolerance:
                return node
        return None

    def redraw(self):
        self.ax.clear()
        self.ax.set_xlim(0, 1)
        self.ax.set_ylim(0, 1)
        self.ax.set_xticks([])
        self.ax.set_yticks([])
        self.ax.set_title(
            "Add node: Left click (label prompted) | Add edge: Right click | Rename: 'l' | "
            "Save: 'v' | Delete node: 'd' | Delete edge: 'e'", fontsize=10)
        nx.draw(self.G, self.pos, ax=self.ax, with_labels=True, labels=self.node_labels, node_color='lightblue')
        self.fig.canvas.draw_idle()

    def save_to_json(self, filename, name):
        # Build merged adjacency keyed by label
        merged_adj = {}
        # Prepare a mapping label -> set of neighbors (by label)
        for node in self.G.nodes:
            label = self.node_labels[node]
            if label not in merged_adj:
                merged_adj[label] = set()
            # Add neighbors of this node by their labels (excluding self loops)
            for neigh in self.G.neighbors(node):
                neigh_label = self.node_labels[neigh]
                if neigh_label != label:  # Avoid self-loop in merged node label
                    merged_adj[label].add(neigh_label)

        # Convert sets to sorted lists
        merged_adj = {k: sorted(v) for k, v in merged_adj.items()}

        graph_data = {
            "name": name,
            "vertices": sorted(merged_adj.keys()),
            "adjacency_list": merged_adj
        }

        existing_data = []

        base_dir = os.path.dirname(os.path.abspath(__file__))
        path = os.path.join(base_dir, '..', 'data', filename)
        
        if os.path.exists(path):
            with open(path, 'r') as f:
                try:
                    existing_data = json.load(f)
                except json.JSONDecodeError:
                    existing_data = []
        existing_data.append(graph_data)
        with open(path, 'w') as f:
            json.dump(existing_data, f, indent=4)
        print(f"Graph '{name}' saved to {filename}")

    def run(self):
        self.ax.set_title(
            "Add node: Left click (label prompted) | Add edge: Right click | Rename: 'l' | "
            "Save: 'v' | Delete node: 'd' | Delete edge: 'e'", fontsize=10)
        self.ax.set_xlim(0, 1)
        self.ax.set_ylim(0, 1)
        self.ax.set_xticks([])
        self.ax.set_yticks([])
        plt.show()


if __name__ == "__main__":
    drawer = GraphDrawer()
    drawer.run()
