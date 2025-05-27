# Install packages if not present
packageList <- c("fitdistrplus", "ggplot2", "getopt")
newPackages <- packageList[! (packageList %in% installed.packages()[,"Package"])]
if (length(newPackages)) install.packages(newPackages)

# Parse args
spec <- matrix(c('help',    'h', 0, "logical",
                 'input',   'i', 1, "character",
                 'pvalue1', 'p', 1, "numeric",
                 'pvalue2', 'P', 1, "numeric",
                 'plot',    't', 1, "character",
                 'output1', 'o', 1, "character",
                 'output2', 'O', 1, "character"),
               byrow = TRUE, ncol = 4)
opt <- getopt::getopt(spec)

# Print usage if requested
if (! is.null(opt$help)) {
  cat("This tool reads the merged output of PanSel.\nIt computes the most conserved (output1), and most divergent regions (output2), computed by PanSel, as BED files.\nThe plot provides\n - the fit (in dashed green) of the observed distribution (solid black line),\n - the p-value thresholds for the most conserved (dotted blue) and most divergent (dotted red) regions.\n")
  cat(getopt::getopt(spec, usage = TRUE))
  q(status = 1)
}

# Check optional parameters
if (is.null(opt$pvalue1)) {
  opt$pvalue1 <- 0.05
}
if (is.null(opt$pvalue2)) {
  opt$pvalue2 <- 0.05
}
# Check compulsory parameters
if (is.null(opt$input)) {
  stop("Missing input file.")
}

# Parse input file
input <- read.table(opt$input, col.names = c("chr", "start", "end", "id", "index", "strand"))

# Infer bin size
input$size <- input$end - input$start
binSize <- as.numeric(names(sort(-table(input$size)))[1])

# Remove too small or too large bins
input <- input[input$size >= binSize / 2, ]
input <- input[input$size <= binSize * 2, ]

# Remove 0s and 1s (hopefully, few)
d <- input$index
d <- d[d > 0]
d <- d[d < 1]

# Fit with beta
f1 <- fitdistrplus::fitdist(d, "beta")
print(f1)

threshold1 <- qbeta(1 - opt$pvalue1, shape1 = f1$estimate[["shape1"]], shape2 = f1$estimate[["shape2"]])
threshold2 <- qbeta(opt$pvalue2,     shape1 = f1$estimate[["shape1"]], shape2 = f1$estimate[["shape2"]])

# Print outliers (most conserved, least conserved) in BED format
if (! is.null(opt$output1)) {
  output1 <- input[input$index >= threshold1, ]
  write.table(output1, file = opt$output1, quote = FALSE, sep = "\t", col.names = FALSE, row.names = FALSE)
}
if (! is.null(opt$output2)) {
  output2 <- input[input$index <= threshold2, ]
  write.table(output2, file = opt$output2, quote = FALSE, sep = "\t", col.names = FALSE, row.names = FALSE)
}

# Plot
if (! is.null(opt$plot)) {
  p <- ggplot2::ggplot(data.frame(data = d), ggplot2::aes(data)) +
    ggplot2::geom_freqpoly(ggplot2::aes(y = ggplot2::after_stat(density)), binwidth = 0.001) +
    ggplot2::stat_function(fun = dbeta, n = 1000, args = list(shape1 = f1$estimate[["shape1"]], shape2 = f1$estimate[["shape2"]]), color = "darkgreen", linetype = "dashed") +
    ggplot2::geom_vline(xintercept = threshold1, linetype = "dotted", color = "darkblue") +
    ggplot2::geom_vline(xintercept = threshold2, linetype = "dotted", color = "darkred") +
    ggplot2::xlab("Jaccard index")
  ggplot2::ggsave(opt$plot, p)
}

q(status = 0)
