#! /usr/bin/env python3

import sys


class Node:

  def __init__(self, name: str, size: int):
    self.name = name
    self.size = size

  def __repr__(self) -> str:
   return self.name


class Path:

  def __init__(self, name: str):
    self.name  = name
    self.nodes = []

  def add_node(self, node: Node):
    self.nodes.append(node)

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
    is_in = False
    output = []
    for n in self.nodes:
      if n.name == n_start:
        is_in = True
      elif n.name == n_end:
        return output
      # Do not include the first node
      elif is_in:
        output.append(n.name)
    # This should never occur
    return output

  def __repr__(self) -> str:
    s = f"{self.name}:"
    for n in self.nodes:
      s += " " + repr(n)
    return s


class Graph:

  def __init__(self):
    self.nodes = {}
    self.paths = {}

  def __repr__(self) -> str:
    s = ""
    for p in self.paths.values():
      s += repr(p) + "\n"
    return s

  def find_common_nodes(self) -> list:
    n_paths = len(self.paths)
    node_count = dict(zip(self.nodes.keys(), [0] * len(self.nodes)))
    for path in self.paths.values():
      # The same node can be visited several times
      for node in set(path.nodes):
        node_count[node.name] += 1
    count = [0] * (n_paths + 1)
    for c in node_count.values():
      count[c] += 1
    for i, c in enumerate(count):
      print(f"{i} -> {c}")
    return [n for n in self.nodes.keys() if node_count[n] == n_paths]

  def sub_paths(self, n_start: str, n_end: str) -> list:
    """
    Extract the nodes between the two given endpoints in all paths.
    Beware: endpoint should be in all paths.
    """
    return [path.sub_path(n_start, n_end) for path in self.paths.values()]



class Parser:

  def __init__(self, fileName: str):
    self.fileName = fileName

  def parse_node(self, line: str) -> Node:
    line = line.strip().split()
    return Node(line[1], len(line[2]))

  def parse_path(self, line: str, g: Graph) -> Path:
    line = line.strip().split()
    path = Path(line[1])
    for n in line[2].split(','):
      n = n.strip("+-")
      path.add_node(g.nodes[n])
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
    print(f"{len(g.nodes)} nodes, {len(g.paths)} paths", file=sys.stderr)
    return g

def count_n_paths(paths: list) -> int:
  return len(set(map(frozenset, paths)))
  
  
  

def main():
  genome_file_name = sys.argv[1]
  reference        = sys.argv[2]
  parser           = Parser(genome_file_name)
  graph            = parser.parse_file()
  common_nodes     = graph.find_common_nodes()
  reference_path   = graph.paths[reference]
  common_nodes     = reference_path.order_nodes(common_nodes)
  print(common_nodes)
  for n_start, n_end in zip(common_nodes, common_nodes[1:]):
    sub_paths   = graph.sub_paths(n_start, n_end)
    n_sub_paths = count_n_paths(sub_paths)
    #print(sub_paths)
    print(f"{n_start} {n_end} --> {n_sub_paths}")

if __name__ == "__main__":
  main()
