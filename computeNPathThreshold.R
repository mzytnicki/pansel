# Install packages if not present
packageList <- c("fitdistrplus", "ggplot2", "getopt")
newPackages <- packageList[! (packageList %in% installed.packages()[,"Package"])]
if (length(newPackages)) install.packages(newPackages)

# Parse args
spec <- matrix(c('help',   'h', 0, "logical",
                 'input',  'i', 1, "character",
                 'output', 'o', 1, "character"),
               byrow = TRUE, ncol = 4)
opt <- getopt::getopt(spec)

# Print usage if requested
if (! is.null(opt$help)) {
  cat(getopt::getopt(spec, usage = TRUE))
  q(status = 1)
}

# Check compulsory parameters
if (is.null(opt$input)) {
  stop("Missing input file.")
}
if (is.null(opt$output)) {
  stop("Missing output file.")
}

# Parse input file
d <- read.table(opt$input, col.names = c("chr", "start", "end", "id", "n.diff.paths", "strand"))
n <- 100
x <- d$n.diff.paths
x <- (x - min(x) + 0.001) / (max(x) - min(x) + 0.002) # Rescale to avoid 0 and 1, not good for MLE
d$n.diff.paths <- x

# Fit Beta distribution, and find thresholds
fitB <- fitdistrplus::fitdist(d$n.diff.paths, "beta")
print(fitB)
threshold <- qbeta(0.05, shape1 = fitB$estimate[["shape1"]], shape2 = fitB$estimate[["shape2"]])
print(paste0("Estimated threshold: ", threshold))

# Plot distribution
p <- ggplot2::ggplot(d, ggplot2::aes(n.diff.paths)) +
	ggplot2::geom_freqpoly(ggplot2::aes(y = ggplot2::after_stat(density)), binwidth = 1 / n, color = "black") +
	ggplot2::stat_function(fun = dbeta, n = n, args = list(shape1 = fitB$estimate[["shape1"]], shape2 = fitB$estimate[["shape2"]]), linetype = "dashed", color = "darkgray") +
	ggplot2::xlab("# paths") +
	ggplot2::ylab("Density") +
        ggplot2::geom_vline(xintercept = threshold, linetype = "dashed", color = "darkgray")
ggplot2::ggsave(opt$output, p)
