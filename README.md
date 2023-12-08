# pansel

## Aim

`pansel` aims at finding over/under diverse regions.

### How it works?

The tool considers a pangenome graph, and a reference haplotype.
It cuts the haplotype into fixed size bins, and computes the number of paths that are found in each bin.
The bins with low numbers are probably under selection.


### Implementation details

In practice, the number of paths between two genomic positions cannot be always computed.
The easiest is to find nodes that are present in "many" haplotypes, that we call *anchor nodes* and compute the number of paths between these nodes.
However, these nodes may not be located at each end of the bins.
In these cases, we find the closest anchor nodes, which are located outside of the bins, and compute the number of paths between these nodes.
This way, the number of paths may be over-estimated, but not under-estimated.


## Compile

Typing `make` with a fairly decent C++ compiler (compatible with C++11) should do.


## Usage

    pansel [parameters] > output_file 2> log_file

    Compulsory parameters:
      -i string: file name in GFA format
      -r string: reference path name (should be in the GFA)
    Optional parameters:
      -n int: min # paths
    Other:
      -h: print this help and exit
      -v: print version number to stderr


### Parameters

 - The GFA file should not be rGFA, and contain segments (`S`) and full length paths (`P`).
     Other lines are unused.
     This GFA should only store one chromosome.
 - The reference path name should be the name of a `P` line in the GFA file.
 - The `-n` parameter is a threshold, that help selecting highly conserved nodes.
     The nodes that are traversed by at least *n* different paths are selected this way.
     If this parameter is not provided, it will be computed by the programme.
     Briefly, it counts the number of times each node is traversed, and takes the mode of the distribution (with *n* > 3).


### Output files

#### Standard output

It is a flat, tabulation-separated file.
The meaning is:

   1. An ID of the bin.
   2. The targeted start position of the bin.
   3. The targeted end position of the bin.
   4. The number of different paths from first anchor node to the last anchor node (2 identical paths will be counted once).
   5. The number of paths from first anchor node to the last anchor node (2 identical paths will be counted twice).
   6. The start position used (is different from the targeted start position when no anchor node overlaps in the bin start position).
   7. The end position used (is different from the targeted end position when no anchor node overlaps in the bin end position).
   8. The name of the left-most anchor node.
   9. The start position of the left-most anchor node.
  10. The end position of the left-most anchor node.
  11. The name of the right-most anchor node.
  12. The start position of the right-most anchor node.
  13. The end position of the right-most anchor node.

Notes:

 - An anchor node may cover the whole bin.
     In this case, the number of different paths is 1, and the left-most anchor node is equal to the right-most anchor node.

#### Standard error

This file contains different statistics on the GFA file, as well as the reference path.
