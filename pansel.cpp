#include <string>
#include <iostream>
#include <fstream>
#include <sstream>
#include <vector>
#include <unordered_map>
#include <algorithm>
#include <cassert>

static const char VERSION[] = "1.02.0";

// A Node contains:
//  - the size of the sequence
struct Node {
  int size;

  Node (int s): size(s) {}
};


// A PlacedNode contains:
//  - the id of the node
//  - the start position, with respect to a given path
//  - the end position, with respect to a given path
struct PlacedNode {
  int id;
  int start;
  int end;

  PlacedNode (): id(-1), start(-1), end(-1) {}
  PlacedNode (int i, int s, int e): id(i), start(s), end(e) {}

  void offset (int o) {
    ++id;
    start += o;
    end   += o;
  }

  bool isSet () const {
    return (id >= 0);
  }

  bool isAfter (const PlacedNode &n) const {
    return (start > n.end);
  }

  bool endsAfter (const PlacedNode &n) const {
    return (end >= n.end);
  }

  bool startsBefore (const PlacedNode &n) const {
    return (start <= n.start);
  }
};


// A SubPath contains:
//  - a list of indices of Node
struct SubPath {
  std::vector < int > nodeIds;

  std::size_t size () const {
    return nodeIds.size();
  }

  void resize (std::size_t i) {
    nodeIds.resize(i);
  }

  void sort () {
    std::sort(nodeIds.begin(), nodeIds.end());
  }

  int operator[] (std::size_t i) const { return nodeIds[i]; }
  int &operator[] (std::size_t i) { return nodeIds[i]; }

  friend bool operator== (const SubPath &p1, const SubPath& p2) {
    if (p1.size() != p2.size()) return false;
    for (std::size_t i = 0; i < p1.size(); ++i) {
      if (p1[i] != p2[i]) return false;
    }
    return true;
  }
};

// A Path contains:
//  - a name
//  - a (possibly empty) hapid
//  - a (possibly empty) seqid
//  - a start position (w.r.t. the genome sequence)
//  - a list of indices of Node
//  - a dictionary that gives the position of a Node in the previous list, given its id
struct Path {
  std::string name;
  std::string hapId;
  std::string seqId;
  unsigned long start;
  std::vector < int > nodeIds;
  std::unordered_map < int, int > hashNodes;

  Path (std::string &n): name(n), start(0) {}

  Path (std::string &n, std::string &h, std::string &i, unsigned long s): name(n), hapId(h), seqId(i), start(s) {}

  std::size_t size () const {
    return nodeIds.size();
  }

  int operator[] (std::size_t i) const { return nodeIds[i]; }
  int &operator[] (std::size_t i) { return nodeIds[i]; }

  void addNode (int nodeId) {
    // In case of loop, this will keep the last occurrence
    hashNodes[nodeId] = nodeIds.size();
    nodeIds.push_back(nodeId);
  }

  bool hasNodeId (int nodeId) {
    return (hashNodes.find(nodeId) != hashNodes.end());
  }

  // Get a series of nodes, and reorder them, following this path.
  void orderNodes (std::vector < int > &inputNodes, std::vector < int > &outputNodes) {
    outputNodes.reserve(inputNodes.size());
    for (int nodeId: inputNodes) {
      if (hasNodeId(nodeId)) {
        outputNodes.push_back(nodeId);
      }
    }
    outputNodes.shrink_to_fit();
    std::sort(outputNodes.begin(), outputNodes.end(), [this](int a, int b) {return this->hashNodes[a] < this->hashNodes[b];});
  }

  // Extract the nodes between the two given endpoints
  // Sort them
  void subPath (int nStart, int nEnd, SubPath &sub) {
    assert(hashNodes.find(nStart) != hashNodes.end());
    assert(hashNodes.find(nEnd) != hashNodes.end());
    int iStart = hashNodes[nStart];
    int iEnd   = hashNodes[nEnd];
    if (iEnd < iStart) {
      std::swap(nStart, nEnd);
      iStart = hashNodes[nStart];
      iEnd   = hashNodes[nEnd];
    }
    int size   = iEnd - iStart + 1;
    sub.resize(size);
    for (int i = 0; i < size; ++i) {
      sub[i] = nodeIds[i + iStart];
    }
    sub.sort();
  }
};


// A Graph contains:
//  - a list of Node
//  - a hash of node name to id of the previous list
//  - a list of Path
//  - the number of path that traverse each node
//  - the set of "common" nodes
struct Graph {
  std::vector < Node > nodes;
  std::vector < std::string > nodeNames;
  std::unordered_map < std::string, int > nodeIds;
  std::vector < Path > paths;
  std::vector < int > nPaths;
  std::vector < int > commonNodes;

  Path &getPath (std::string &pathName) {
    for (Path &path: paths) {
      if (path.name == pathName) {
        return path;
      }
    }
    std::cerr << "Error!  Cannot find path with name '" << pathName << "'.\nExiting.\n";
    exit(EXIT_FAILURE);
  }

  Path &getPath (std::string &pathName, std::string &seqId) {
    for (Path &path: paths) {
      if ((path.name == pathName) && (path.seqId == seqId)) {
        return path;
      }
    }
    std::cerr << "Error!  Cannot find path with name '" << pathName << ":" << seqId << "'.\nExiting.\n";
    exit(EXIT_FAILURE);
  }

  Path &getOrCreatePath (std::string &pathName, std::string &hapId, std::string &seqId, unsigned long start) {
    for (Path &path: paths) {
      if ((path.name == pathName) && (path.hapId == hapId) && (path.seqId == seqId)) {
        return path;
      }
    }
    paths.emplace_back(pathName, hapId, seqId, start);
    return paths.back();
  }

  // Copy all the seq ids for the path name
  void getSeqIds(std::string &pathName, std::vector < std::string > &seqIds) {
    for (Path &path: paths) {
      if (path.name == pathName) {
        seqIds.push_back(path.seqId);
      }
    }
  }

  void addNode (std::string &name, int size) {
    nodeIds[name] = nodes.size();
    nodes.emplace_back(size);
    nodeNames.push_back(name);
  }

  // This will decide the min # paths per nodes
  // Rule of thumb: the argmax of the counts, starting after 3
  int getMinNPathsThreshold (std::vector < int > &counts) {
    if (counts.size() < 3) {
      std::cerr << "Error!\nThere are less than 3 paths.\n.Exiting.\n";
      exit(EXIT_FAILURE);
    }
    int m = 0;
    int a = -1;
    for (std::size_t i = 3; i < counts.size(); ++i) {
      if (counts[i] > m) {
        m = counts[i];
        a = i;
      }
    }
    if (a == -1) {
      std::cerr << "Error!\nThe paths do not match the nodes.\n.Exiting.\n";
      exit(EXIT_FAILURE);
    }
    std::cerr << "\t" << "Using a threshold of " << a << ".\n";
    return a;
  }

  // Compute, for each node, the number of paths it belongs to.
  // Store into "commonNodes" the most frequent nodes (above the given threshold)
  void findCommonNodes (int &minNPaths) {
    nPaths.resize(nodes.size());
    for (Path &path: paths) {
      // In case of cycle, a path may visit the same node several times.
      // This will count nodes at most once per path.
      for (const auto &p: path.hashNodes) {
        ++nPaths[p.first];
      }
    }
    std::vector < int > counts (paths.size() + 1, 0);
    for (int i: nPaths) {
      ++counts[i];
    }
    std::cerr << "Number of paths per node distribution:\n";
    for (std::size_t i = 0; i < counts.size(); ++i) {
      if (counts[i] > 0) {
        std::cerr << "\t" << i << " -> " << counts[i] << "\n";
      }
    }
    if (minNPaths == -1) {
      minNPaths = getMinNPathsThreshold (counts);
    }
    int nNodes = 0;
    for (std::size_t i = 0; i < nPaths.size(); ++i) {
      if (nPaths[i] >= minNPaths) {
        ++nNodes;
      }
    }
    commonNodes.reserve(nNodes);
    for (std::size_t i = 0; i < nPaths.size(); ++i) {
      if (nPaths[i] >= minNPaths) {
        commonNodes.push_back(i);
      }
    }
    commonNodes.shrink_to_fit();
  }

  double getJaccard (SubPath &sub1, SubPath &sub2) {
    std::size_t s1 = sub1.size();
    std::size_t s2 = sub2.size();
    std::size_t i1 = 0;
    std::size_t i2 = 0;
    double n_inter = 0;
    double n_union = 0;
    // Sweep through the two sub-paths
    // Supposes that they are ordered
    while ((i1 < s1) && (i2 < s2)) {
      int n1 = sub1[i1];
      int n2 = sub2[i2];
      if (n1 == n2) {
        n_inter += nodes[n1].size;
        n_union += nodes[n1].size;
        ++i1;
        ++i2;
      }
      else if (n1 < n2) {
        n_union += nodes[n1].size;
        ++i1;
      }
      else {
        n_union += nodes[n2].size;
        ++i2;
      }
    }
    for (; i1 < s1; ++i1) {
      n_union += nodes[sub1[i1]].size;
    }
    for (; i2 < s2; ++i2) {
      n_union += nodes[sub2[i2]].size;
    }
    if (n_union == 0) return 0;
    return (n_inter / n_union);
  }

  void countNPaths (int nStart, int nEnd, int &nTotalPaths, int &nDifferentPaths, float &jaccard) {
    std::vector < SubPath > subPaths;
    nTotalPaths     = 0;
    nDifferentPaths = 1;
    jaccard         = 0.0;
    for (Path &path: paths) {
      if ((path.hasNodeId(nStart)) && (path.hasNodeId(nEnd))) {
        SubPath newSubPath;
        ++nTotalPaths;
        path.subPath(nStart, nEnd, newSubPath);
        subPaths.push_back(newSubPath);
      }
    }
    subPaths.shrink_to_fit();
    for (std::size_t i = 1; i < subPaths.size(); ++i) {
      bool foundEqual = false;
      for (std::size_t j = 0; j < i; ++j) {
        double d = getJaccard(subPaths[i], subPaths[j]);
        if (d == 1) {
          foundEqual = true;
        }
        jaccard += d;
      }
      if (! foundEqual) {
        ++nDifferentPaths;
      }
    }
   jaccard /= nTotalPaths * (nTotalPaths - 1) / 2;
  }
};


struct Parser {
  std::ifstream inputFile;
  Graph        &graph;

  Parser (std::string &fileName, Graph &g): inputFile(fileName), graph(g) {
    if (! inputFile.is_open()) {
      std::cerr << "Error!  Cannot open input file '" << fileName << "'.\nExiting.\n";
      exit(EXIT_FAILURE);
    }
  }

  void parseNode (std::string &line) {
    std::istringstream formattedLine(line);
    char tag;
    std::string name, sequence;
    formattedLine >> tag >> name >> sequence;
    graph.addNode(name, sequence.length());
  }

  void parsePath (std::string &line) {
    // Nodes should be parsed. Adapt vector sizes
    graph.nodes.shrink_to_fit();
    graph.nodeNames.shrink_to_fit();
    std::istringstream formattedLine(line);
    char tag;
    std::string pathName, mergedPath;
    formattedLine >> tag >> pathName >> mergedPath;
    // Path with names "_MINIGRAPH_.sXXXX" are spurious.
    // Remove them.
    if (pathName.find("_MINIGRAPH_") == std::string::npos) {
      std::istringstream formattedPath(mergedPath);
      graph.paths.emplace_back(pathName);
      std::string nodeName;
      while (std::getline(formattedPath, nodeName, ',')) {
        // Last char is the direction. Remove it.
        nodeName.pop_back();
        int nodeId = graph.nodeIds[nodeName];
        graph.paths.back().addNode(nodeId);
      }
    }
  }

  void parseWalk (std::string &line) {
    // Nodes should be parsed. Adapt vector sizes
    graph.nodes.shrink_to_fit();
    graph.nodeNames.shrink_to_fit();
    std::istringstream formattedLine(line);
    char tag;
    unsigned long start, end;
    std::string pathName, hapIndex, seqId, mergedPath;
    formattedLine >> tag >> pathName >> hapIndex >> seqId >> start >> end >> mergedPath;
    // If the same walk (name, hapId, seqId) is seen several times, just append the paths.
    // This is a bug if the reference path is split.
    // Otherwise, there should be minimal impact.
    Path &path = graph.getOrCreatePath(pathName, hapIndex, seqId, start);
    // Do not insert strand
    unsigned int stringStart = 1;
    for (unsigned int stringEnd = 1; stringEnd < mergedPath.size(); ++stringEnd) {
      if ((mergedPath[stringEnd] == '>') || (mergedPath[stringEnd] == '<')) {
        // Do not insert strand
        int nodeId = graph.nodeIds[mergedPath.substr(stringStart, stringEnd - stringStart)];
        path.addNode(nodeId);
        stringStart = stringEnd + 1;
      }
    }
    // Insert last node
    int nodeId = graph.nodeIds[mergedPath.substr(stringStart)];
    path.addNode(nodeId);
  }

  void parseFile () {
    std::string line;
    while (std::getline(inputFile, line)) {
      if (! line.empty()) {
        if (line[0] == 'S') {
          parseNode(line);
        }
        else if (line[0] == 'P') {
          parsePath(line);
        }
        else if (line[0] == 'W') {
          parseWalk(line);
        }
      }
    }
    graph.paths.shrink_to_fit();
    for (Path &path: graph.paths) {
      path.nodeIds.shrink_to_fit();
    }
    std::cerr << "Read file with " << graph.nodes.size() << " segments and " << graph.paths.size() << " paths.\n";
  }
};

void printPlacedNode(PlacedNode &n, Graph &g) {
  std::cout << g.nodeNames[n.id] << "\t" << n.start << "\t" << n.end;
}

void computeNPaths (Graph &graph, Path &referencePath, std::vector < int > &orderedCommonNodes, int chunkSize, bool bedFormat, std::string &chrName) {
  std::vector < bool > orderedCommonNodesBool (graph.nodes.size(), false);
  for (int nodeId: orderedCommonNodes) {
    orderedCommonNodesBool[nodeId] = true;
  }
  int        length         = 1;
  int        firstNodeId    = referencePath.nodeIds.front();
  PlacedNode currentChunk(0, 1 + referencePath.start, chunkSize + referencePath.start);
  PlacedNode startNode;
  PlacedNode commonNode;
  if (orderedCommonNodesBool[firstNodeId]) {
    startNode.id    = firstNodeId;
    startNode.start = 1 + referencePath.start;
    startNode.end   = graph.nodes[firstNodeId].size + referencePath.start;
  }
  // Follow the reference path
  for (std::size_t i = 0; i < referencePath.size(); ++i) {
    int nodeId = referencePath.nodeIds[i];
    Node &node = graph.nodes[nodeId];
    PlacedNode currentNode(nodeId, length, length + node.size - 1);
    bool  inCommon  = (orderedCommonNodesBool[nodeId]);
    if (currentNode.endsAfter(currentChunk)) {
      if (inCommon) {
        if (startNode.isSet()) {
          int nTotalPaths, nDifferentPaths;
          float jaccard;
          graph.countNPaths(startNode.id, currentNode.id, nTotalPaths, nDifferentPaths, jaccard);
          int chunkStart = ((startNode.start   <= currentChunk.start) && (currentChunk.start <= startNode.end))?   currentChunk.start: startNode.end;
          int chunkEnd   = ((currentNode.start <= currentChunk.end)   && (currentChunk.end   <= currentNode.end))? currentChunk.end:   currentNode.start;
          if (bedFormat) {
            std::cout << chrName << "\t" << chunkStart << "\t" << chunkEnd << "\tregion_" << currentChunk.id << "\t" << jaccard << "\t+\n";
          }
          else {
            std::cout << currentChunk.id << "\t" << chunkStart << "\t" << chunkEnd << "\t" << jaccard << "\t" << nDifferentPaths << "\t" << nTotalPaths << "\t" << currentChunk.start << "\t" << currentChunk.end << "\t";
            printPlacedNode(startNode, graph);
            std::cout << "\t";
            printPlacedNode(currentNode, graph);
            std::cout << "\n";
          }
        }
        // If the chunk starts after this common node, take the previous common node
        // This overestimates the size
        if (currentNode.isAfter(currentChunk)) {
          startNode = commonNode;
        }
        else {
          startNode = currentNode;
        }
        while (currentNode.endsAfter(currentChunk)) {
          // The current node covers the whole chunk: stats are straightforward
          if ((currentNode.startsBefore(currentChunk)) && (currentNode.endsAfter(currentChunk))) {
            if (bedFormat) {
              std::cout << chrName << "\t" << currentChunk.start << "\t" << currentChunk.end << "\tregion_" << currentNode.id << "\t1\t+\n";
            }
            else {
              std::cout << currentChunk.id << "\t" << currentChunk.start << "\t" << currentChunk.end << "\t0\t1\t" << graph.nPaths[currentNode.id] << "\t" << currentChunk.start << "\t" << currentChunk.end << "\t";
              printPlacedNode(currentNode, graph);
              std::cout << "\t";
              printPlacedNode(currentNode, graph);
              std::cout << "\n";
            }
          }
          currentChunk.offset(chunkSize);
        }
      }
    }
    if (inCommon) {
      commonNode = currentNode;
    }
    length += node.size;
    if (i % 10000 == 0) {
      std::cerr << i << "/" << referencePath.size() << " nodes visited.\r" << std::flush;
    }
  }
  std::cerr << referencePath.size() << "/" << referencePath.size() << " nodes visited.\n";
}

void readReferencePath (Graph &graph, Path &referencePath, int chunkSize, int minNPaths, bool bedFormat, std::string &chrName) {
  long referenceSize  = 0;
  for (int nodeId: referencePath.nodeIds) {
    referenceSize += graph.nodes[nodeId].size;
  }
  std::cerr << "Reference path '" << referencePath.name;
  if (! referencePath.seqId.empty()) {
    std::cerr << ':' << referencePath.seqId;
  }
  std::cerr << "' contains " << referencePath.nodeIds.size() << " nodes, and " << referenceSize << " nucleotides.\n";
  std::vector < int > orderedCommonNodes;
  referencePath.orderNodes(graph.commonNodes, orderedCommonNodes);
  std::cerr << graph.commonNodes.size() << " nodes are above the threshold, " << orderedCommonNodes.size() << " are in reference path.\n";

  computeNPaths(graph, referencePath, orderedCommonNodes, chunkSize, bedFormat, chrName);
}

void printUsage () {
  puts("Usage:\n"
       "pansel [parameters] > output_file 2> log_file\n\n"
       "Compulsory parameters:\n"
       "  -i string: file name in GFA format\n"
       "  -r string: reference path name (should be in the GFA)\n"
       "Optional parameters:\n"
       "  -z int:    bin size (default: 1000)\n"
       "  -n int:    min # paths\n"
       "  -b:        use BED (shorter) format\n"
       "  -c string: reference name (if the graph contains 1 chromosome, defaut: ref path name)\n"
       "Other:\n"
       "  -h: print this help and exit\n"
       "  -v: print version number to stderr");
  exit(EXIT_SUCCESS);
}

void parseParameters (int argc, char const **argv, std::string &pangenomeFileName, std::string &reference, int &chunkSize, int &minNPaths, bool &bedFormat, std::string &chrName) {
  for (int i = 1; i < argc; ++i) {
    std::string s(argv[i]);
    if (s == "-i") {
      pangenomeFileName = argv[++i];
    }
    else if (s == "-r") {
      reference = argv[++i];
    }
    else if (s == "-z") {
      chunkSize = std::stoi(argv[++i]);
    }
    else if (s == "-n") {
      minNPaths = std::stoi(argv[++i]);
    }
    else if (s == "-b") {
      bedFormat = true;
    }
    else if (s == "-c") {
      chrName = argv[++i];
    }
    else if (s == "-h") {
      printUsage();
    }
    else if (s == "-v") {
      std::cerr << "pansel version " << VERSION << "\n";
    }
    else {
      std::cerr << "Error!\nCannot understand parameter '" << argv[i] << "'.\nExiting.\n";
      exit(EXIT_FAILURE);
    }
  }
  if (pangenomeFileName.empty()) {
    std::cerr << "Error!\nInput pangenome file is missing.\nExiting.\n";
    printUsage();
    exit(EXIT_FAILURE);
  }
  if (reference.empty()) {
    std::cerr << "Error!\nInput path reference name is missing.\nExiting.\n";
    printUsage();
    exit(EXIT_FAILURE);
  }
  if (chrName.empty()) {
    chrName = reference;
  }
}

int main (int argc, const char* argv[]) {
  std::string pangenomeFileName;
  std::string reference;
  std::string chrName;
  int         chunkSize = 1000;
  int         minNPaths = -1;
  bool        bedFormat = false;
  parseParameters(argc, argv, pangenomeFileName, reference, chunkSize, minNPaths, bedFormat, chrName);
  Graph       graph;
  Parser      parser(pangenomeFileName, graph);
  parser.parseFile();
  graph.findCommonNodes(minNPaths);
  if (chrName.empty()) {
    std::vector < std::string > seqIds;
    graph.getSeqIds(reference, seqIds);
    for (std::string &seqId: seqIds) {
      Path &referencePath = graph.getPath(reference, seqId);
      readReferencePath(graph, referencePath, chunkSize, minNPaths, bedFormat, seqId);
    }
  }
  else {
    Path &referencePath = graph.getPath(reference);
    readReferencePath(graph, referencePath, chunkSize, minNPaths, bedFormat, chrName);
  }
  return EXIT_SUCCESS;
}
