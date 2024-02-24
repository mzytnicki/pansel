# Install packages if not present
packageList <- c("MASS", "ggplot2", "getopt")
newPackages <- packageList[! (packageList %in% installed.packages()[,"Package"])]
if (length(newPackages)) install.packages(newPackages)

# Parse args
spec <- matrix(c('help',    'h', 0, "logical",
                 'input',   'i', 1, "character",
                 'binSize', 'b', 1, "integer",
                 'pvalue',  'p', 1, "numeric",
                 'plot',    'P', 1, "character",
                 'output',  'o', 1, "character"),
               byrow = TRUE, ncol = 4)
opt <- getopt::getopt(spec)

# Print usage if requested
if (! is.null(opt$help)) {
  cat(getopt::getopt(spec, usage = TRUE))
  q(status = 1)
}

# Check optional parameters
if (is.null(opt$pvalue)) {
  opt$pvalue <- 0.05
}
# Check compulsory parameters
if (is.null(opt$input)) {
  stop("Missing input file.")
}
if (is.null(opt$binSize)) {
  stop("Missing bin size.")
}
if (is.null(opt$output)) {
  stop("Missing output file.")
}


# Parse input file
d <- read.table(opt$input, col.names = c("chr", "start", "end", "id", "distance", "strand"))
d$nDist <- as.integer(round(d$distance * opt$binSize))

# Compute mode
t <- table(d$nDist)
m <- as.numeric(names(which.max(as.list(t))))

lim  <- m * 2
maxX <- m * 5

# Estimate negative binomial with leftmost part of the distribution
df <- d[d$nDist <= lim, ]
f  <- MASS::fitdistr(df$nDist, densfun = "negative binomial")
threshold <- qnbinom(0.05, size = f$estimate[["size"]], mu = f$estimate[["mu"]])
print(threshold)

outputD <- d
outputD <- outputD[outputD$nDist <= threshold, ]
outputD$nDist <- NULL
write.table(outputD, file = opt$output, quote = FALSE, sep = "\t", col.names = FALSE, row.names = FALSE)

# Plot output
if (is.null(opt$plot)) {
  q(status = 0)
}
p <- ggplot2::ggplot(df, ggplot2::aes(nDist)) + 
    ggplot2::geom_freqpoly(ggplot2::aes(y = ggplot2::after_stat(density)), binwidth = 1, color = "black") +
        ggplot2::stat_function(fun = dnbinom, n = maxX + 1, args = list(size = f$estimate[["size"]], mu = f$estimate[["mu"]]), linetype = "dotted", color = "darkgreen") +
        ggplot2::geom_vline(xintercept = m, linetype = "dotted") +
        ggplot2::geom_vline(xintercept = lim, linetype = "dashed") +
        ggplot2::geom_vline(xintercept = threshold) +
        ggplot2::xlab("Edit distance") +
        ggplot2::xlim(0, maxX)
ggplot2::ggsave(opt$plot, p)
