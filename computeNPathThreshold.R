# Install packages if not present
packageList <- c("MASS", "ggplot2", "getopt")
newPackages <- packageList[! (packageList %in% installed.packages()[,"Package"])]
if (length(newPackages)) install.packages(newPackages)

# Parse args
spec <- matrix(c('help',    'h', 0, "logical",
                 'input',   'i', 1, "character",
                 'binSize', 'b', 1, "integer",
                 'pvalue1', 'p', 1, "numeric",
                 'pvalue2', 'P', 1, "numeric",
                 'plot1',   't', 1, "character",
                 'plot2',   'T', 1, "character",
                 'output1', 'o', 1, "character",
                 'output2', 'O', 1, "character"),
               byrow = TRUE, ncol = 4)
opt <- getopt::getopt(spec)

# Print usage if requested
if (! is.null(opt$help)) {
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
if (is.null(opt$binSize)) {
  stop("Missing bin size.")
}

# Parse input file
d <- read.table(opt$input, col.names = c("chr", "start", "end", "id", "distance", "strand"))
d$nDist <- as.integer(round(d$distance * opt$binSize))

# Compute mode
m <- as.numeric(names(which.max(as.list(table(d$nDist)))))

lim  <- max(5, m * 2)
maxX <- m * 5

# Estimate negative binomial with leftmost part of the distribution
df1 <- d[d$nDist <= lim, ]
f1  <- MASS::fitdistr(df1$nDist, densfun = "negative binomial")
threshold1 <- qnbinom(opt$pvalue1, size = f1$estimate[["size"]], mu = f1$estimate[["mu"]])
print(f1)

# Estimate ??? low with rightmost part of the distribution
df2 <- d[d$nDist >= lim, ]
f2  <- MASS::fitdistr(df2$nDist, densfun = "gamma")
threshold2 <- qgamma(1 - opt$pvalue2, shape = f2$estimate[["shape"]], rate = f2$estimate[["rate"]])
print(f2)

# Print outliers (most conserved, least conserved) in BED format
if (! is.null(opt$output1)) {
  output1 <- d[d$nDist <= threshold1, ]
  write.table(output1, file = opt$output1, quote = FALSE, sep = "\t", col.names = FALSE, row.names = FALSE)
}
if (! is.null(opt$output2)) {
  output2 <- d[d$nDist >= threshold2, ]
  write.table(output2, file = opt$output2, quote = FALSE, sep = "\t", col.names = FALSE, row.names = FALSE)
}

# Plot leftmost output
if (! is.null(opt$plot1)) {
  p <- ggplot2::ggplot(df1, ggplot2::aes(nDist)) + 
    ggplot2::geom_freqpoly(ggplot2::aes(y = ggplot2::after_stat(density)), binwidth = 1, color = "black") +
    ggplot2::stat_function(fun = dnbinom, n = maxX + 1, args = list(size = f1$estimate[["size"]], mu = f1$estimate[["mu"]]), linetype = "dotted", color = "darkgreen") +
    ggplot2::geom_vline(xintercept = m, linetype = "dotted") +
    ggplot2::geom_vline(xintercept = lim, linetype = "dashed") +
    ggplot2::geom_vline(xintercept = threshold1, color = "darkred") +
    ggplot2::xlab("Edit distance") +
    ggplot2::xlim(0, maxX)
    ggplot2::ggsave(opt$plot1, p)
}

# Plot rightmost output
if (! is.null(opt$plot2)) {
  p <- ggplot2::ggplot(df2, ggplot2::aes(nDist)) + 
    ggplot2::geom_freqpoly(ggplot2::aes(y = ggplot2::after_stat(density)), binwidth = 1, color = "black") +
    ggplot2::stat_function(fun = dgamma, n = maxX + 1, args = list(shape = f2$estimate[["shape"]], rate = f2$estimate[["rate"]]), linetype = "dotted", color = "darkgreen") +
    ggplot2::geom_vline(xintercept = m, linetype = "dotted") +
    ggplot2::geom_vline(xintercept = lim, linetype = "dashed") +
    ggplot2::geom_vline(xintercept = threshold2, color = "darkred") +
    ggplot2::xlab("Edit distance") +
    ggplot2::xlim(lim, 5 * maxX)
    ggplot2::ggsave(opt$plot2, p)
}


q(status = 0)
