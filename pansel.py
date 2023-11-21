#! /usr/bin/env python3

import sys


class Node:
  """
  A Node contains:
   - a node name
   - the size of the sequence
  """

  def __init__(self, name: str, size: int):
    self.name  = name
    self.size  = size

  def __repr__(self) -> str:
   return self.name


class PosNode(Node):
  """
  A PosNode is a Node, with:
   - the start position in the sequence
  """

  def __init__(self, name: str, start: int, size: int):
    super().__init__(name, size)
    self.start = start

  def __repr__(self) -> str:
   return f"{self.name}: {self.start}-{self.start+self.size-1}"

  def get_start(self) -> int:
    """
    Return the position of the first nt of the node (1 based)
    """
    return self.start

  def get_end(self) -> int:
    """
    Return the position of the last nt of the node (1 based)
    """
    return self.start + self.size - 1


class Path:
  """
  A Path contains:
   - a name
   - a list of PosNode
   - a dictionary that gives the position of a Node in the previous list, given its name
  """

  def __init__(self, name: str):
    self.name      = name
    self.nodes     = []
    self.hash_node = {}

  def add_node(self, node: Node, pos: int):
    # In case of loop, this will keep the last occurrence
    self.hash_node[node.name] = len(self.nodes)
    self.nodes.append(PosNode(node.name, pos, node.size))

  def get_node(self, node_name: str) -> PosNode:
    """
    Return the PosNode object, given its name.
    In case of loop, the last node is given.
    """
    return self.nodes[self.hash_node[node_name]]

  def has_node(self, node: str) -> bool:
    """
    Return True iff the node name is in the path
    """
    return (node in self.hash_node)

  def has_nodes(self, nodes: list) -> bool:
    """
    Return True iff all the node names are in the path
    """
    return all(map(self.has_node, nodes))

  def order_nodes(self, nodes: list) -> list:
    """
    Get a series of nodes, and reorder them, following this path.
    """
    nodes  = set(nodes)
    output = []
    for n in self.nodes:
      if n.name in nodes:
        output.append(n.name)
        # In case of loops
        nodes.remove(n.name)
    return output

  def sub_path(self, n_start: str, n_end: str) -> list:
    """
    Extract the nodes between the two given endpoints
    """
    return [self.nodes[i].name for i in range(self.hash_node[n_start] + 1, self.hash_node[n_end])]

  def get_node_distance(self, n_start: str, n_end: str) -> int:
    """
    Get the number of nodes bewteen two nodes
    """
    return self.hash_node[n_end] - self.hash_node[n_start]

  def get_nt_distance(self, n_start: str, n_end: str) -> int:
    """
    Get the number of nucleotides between two nodes
    """
    s = 0
    for i in range(self.hash_node[n_start] + 1, self.hash_node[n_end]):
      s += self.nodes[i].size
    return s

  def __repr__(self) -> str:
    s = f"{self.name}:"
    for n in self.nodes:
      s += " " + repr(n)
    return s


class Graph:
  """
  A Graph contains:
   - a dict of Node, indexed by their name
   - a dict of Path, indexed by their name
  """

  def __init__(self):
    self.nodes = {}
    self.paths = {}

  def __repr__(self) -> str:
    s = ""
    for p in self.paths.values():
      s += repr(p) + "\n"
    return s

  def find_common_nodes(self, min_n_paths) -> list:
    """
    Compute, for each node, the number of paths it belongs to.
    Return the most frequent nodes (above the given threshold)
    """
    n_paths = len(self.paths)
    node_count = dict(zip(self.nodes.keys(), [0] * len(self.nodes)))
    for path in self.paths.values():
      # The same node can be visited several times
      for node in path.hash_node.keys():
        node_count[node] += 1
    count = [0] * (n_paths + 1)
    for c in node_count.values():
      count[c] += 1
    print("Number of paths per node distribution:", file=sys.stderr)
    for i, c in enumerate(count):
      if c > 0:
        print(f"\t{i} -> {c}", file=sys.stderr)
    return [n for n in self.nodes.keys() if node_count[n] >= min_n_paths]

  def sub_paths(self, n_start: str, n_end: str) -> list:
    """
    Extract the nodes between the two given endpoints in all paths.
    Check that the nodes in the paths are present beforehand.
    """
    return [path.sub_path(n_start, n_end) for path in self.paths.values() if path.has_nodes([n_start, n_end])]



class Parser:

  def __init__(self, fileName: str):
    self.fileName = fileName

  def parse_node(self, line: str) -> Node:
    line = line.strip().split()
    return Node(line[1], len(line[2]))

  def parse_path(self, line: str, g: Graph) -> Path:
    line = line.strip().split()
    path = Path(line[1])
    pos  = 1
    for n in line[2].split(','):
      n = n.strip("+-")
      path.add_node(g.nodes[n], pos)
      pos += g.nodes[n].size
    return path

  def parse_file(self) -> Graph:
    g = Graph()
    with open(self.fileName, 'r') as f:
      for l in f:
        if l:
          if l[0] == 'S':
            n = self.parse_node(l)
            g.nodes[n.name] = n
          elif l[0] == 'P':
            p = self.parse_path(l, g)
            g.paths[p.name] = p
    print(f"Read graph with {len(g.nodes)} nodes and {len(g.paths)} paths.", file=sys.stderr)
    return g


def count_n_paths(paths: list) -> int:
  return len(set(map(frozenset, paths)))
  
  

def main():
  genome_file_name = sys.argv[1]
  reference        = sys.argv[2]
  min_n_paths      = int(sys.argv[3])
  parser           = Parser(genome_file_name)
  graph            = parser.parse_file()
  common_nodes     = graph.find_common_nodes(min_n_paths)
  reference_path   = graph.paths[reference]
  common_nodes     = reference_path.order_nodes(common_nodes)
  print(f"{len(common_nodes)} nodes are above the thresold.", file=sys.stderr)
  print(f"node start\tnode end\tref start\tref end\t# paths\t# nodes ref\tref size\t# paths / ref size")
  #print(common_nodes)
  n_used_intervals = 0
  for n_start, n_end in zip(common_nodes, common_nodes[1:]):
    if reference_path.get_node_distance(n_start, n_end) > 1:
      sub_paths   = graph.sub_paths(n_start, n_end)
      n_sub_paths = count_n_paths(sub_paths)
      nt_size     = reference_path.get_nt_distance(n_start, n_end)
      density     = float(n_sub_paths) / float(nt_size)
      start       = reference_path.get_node(n_start).get_end() + 1
      end         = reference_path.get_node(n_end).get_start() - 1
      #print(sub_paths)
      print(f"{n_start}\t{n_end}\t{start}\t{end}\t{n_sub_paths}\t{len(sub_paths)}\t{nt_size}\t{density}")
      n_used_intervals += 1
  print(f"{n_used_intervals} intervals considered.", file=sys.stderr)
  

if __name__ == "__main__":
  main()
