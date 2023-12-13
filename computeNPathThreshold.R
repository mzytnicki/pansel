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
n <- max(d$n.diff.paths) - min(d$n.diff.paths) + 1

# Fit Gamma distribution, and find thresholds
fitG <- fitdistrplus::fitdist(d$n.diff.paths, "gamma")
threshold <- qgamma(0.05, shape = fitG$estimate[["shape"]], rate = fitG$estimate[["rate"]])
print(paste0("Estimated threshold: ", threshold))

# Plot distribution
p <- ggplot2::ggplot(d, ggplot2::aes(n.diff.paths)) +
	ggplot2::geom_freqpoly(ggplot2::aes(y = ggplot2::after_stat(density)), binwidth = 1, color = "black") +
	ggplot2::stat_function(fun = dgamma, n = n, args = list(shape = fitG$estimate[["shape"]], rate = fitG$estimate[["rate"]]), linetype = "dashed", color = "darkgray") +
	ggplot2::xlab("# paths") +
	ggplot2::ylab("Density") +
        ggplot2::geom_vline(xintercept = threshold, linetype = "dashed", color = "darkgray")
ggplot2::ggsave(opt$output, p)
