# `pansel`

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
      -z int:    bin size (default: 1000)
      -n int:    min # paths
      -b:        use BED (shorter) format
      -c string: reference name (if the graph contains 1 chromosome)
    Other:
      -h: print this help and exit
      -v: print version number to stderr


### Parameters

 - The bin size is the distance between two anchor nodes that will be considered.
 - The `-n` parameter is a threshold, that help selecting highly conserved nodes.
     The nodes that are traversed by at least *n* different paths are selected this way.
     If this parameter is not provided, it will be computed by the programme.
     Briefly, it counts the number of times each node is traversed, and takes the mode of the distribution (with *n* > 3).


### Input GFA file format

The GFA format is not standardized yet.
PanSel needs minimal information in order to deduce chromosomes from paths.

 - The GFA file should not be rGFA, and contain segments (`S`) and full length paths (`P`) or walks (`W`).
     Other lines are unused.
 - This GFA can only store one or several chromosomes.
 - The reference path name should be the second field of a `P` line (`PathName`) or a `W` line (`SampleId`) in the GFA file.
 - If the GFA file contains one chromosome, you can provide the name of this chromosome (to appear in the output file) using parameter `-c`.
 - If the GFA file contains several chromosomes, only `W` lines are supported, and the name of the chromosome should be the fourth field (`SeqId`).
 - The reference should not be split into several contigs.

### Output files

#### Standard output

It is a flat, tabulation-separated file.
The meaning is:

   1. An ID of the bin.
   2. The targeted start position of the bin.
   3. The targeted end position of the bin.
   4. The Jaccard index between each pair of paths from first anchor node to the last anchor node.
   5. The number of different paths from first anchor node to the last anchor node (2 identical paths will be counted once).
   6. The total number of paths from first anchor node to the last anchor node (2 identical paths will be counted twice).
   7. The start position used (is different from the targeted start position when no anchor node overlaps in the bin start position).
   8. The end position used (is different from the targeted end position when no anchor node overlaps in the bin end position).
   9. The name of the left-most anchor node.
  10. The start position of the left-most anchor node.
  11. The end position of the left-most anchor node.
  12. The name of the right-most anchor node.
  13. The start position of the right-most anchor node.
  14. The end position of the right-most anchor node.

Notes:

 - An anchor node may cover the whole bin.
     In this case, the number of different paths is 1, and the left-most anchor node is equal to the right-most anchor node.

#### BED output

The alternative is a [BED format](https://en.wikipedia.org/wiki/BED_(file_format)), where the Jaccard index is provided as the fifth field (`score`).


#### Standard error

This file contains different statistics on the GFA file, as well as the reference path.

## Testing `pansel`

You can use `pansel` on a small sample, provided by the [BubbleGun](https://github.com/fawaz-dabbaghieh/bubble_gun) package:

    wget -c https://zenodo.org/record/7937947/files/ecoli50.gfa.zst
    ./pansel -i <( zstd -d -c ecoli50.gfa.zst ) -r GCF_019614135.1#1#NZ_CP080645.1 -b > ecoli.bed 2> ecoli.log

## Example of real use

This will detail an example of a real use of `pansel`.

### Step 1

Download the HPRC data (1 file per chromosome, restrict to autosomes), and tranform from VG to GFA format using `vg view`:

    for i in `seq 1 22`
    do
      wget https://s3-us-west-2.amazonaws.com/human-pangenomics/pangenomes/scratch/2022_03_11_minigraph_cactus/chrom-graphs-hprc-v1.1-mc-chm13-full/chr${i}.vg
      vg view chr${i}.vg | gzip -c > chr${i}.gfa.gz
      rm chr${i}.vg
    done

### Step 2

 Run `pansel` on each file:

    for i in `seq 1 22`
    do
      /usr/bin/time ./pansel -i <( zcat chr${i}.gfa.gz ) -r GRCh38.0.chr${i} -c chr${i} -n 91 -b
    done > chrall.bed 2> chrall.log

### Step 3

Fit distributions to the number of paths, and get the 5% threshold for the most conserved, and the most divergent regions (the R script file is included in the repository):

    Rscript getExtremes.R -i chrall.bed -p 0.05 -P 0.05 -t fit.png -o fit_conserved.bed -O fit_divergent.bed &> fit.log

The parameters are:

    -i string:  the input file, output of the previous step
    -p float:   the p-value threshold of the conserved regions
    -o string:  the conserved regions, in BED format
    -P float:   the p-value threshold of the divergent regions
    -O string:  the divergent regions, in BED format
    -t string:  a plot of the fit (observed: solid black, fit: dashed green, conserved threshold: dotted blue, divergent threshold: dotted red)
    -h:         a help message

## How to build my pangenome graph?

There are many ways to do so.
One possibility is to use a dedicated pipe-line: the [nf-core pangenome pipe-line](https://nf-co.re/pangenome/).
Otherwise, you can follow the procedure I used to [build a small pangenome](https://github.com/mzytnicki/pansel_paper) (see Create graph for *M_xanthus*).
