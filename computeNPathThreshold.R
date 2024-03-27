# Install packages if not present
packageList <- c("fitdistrplus", "ggplot2", "getopt")
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

lim1  <- max(5, m * 2)
lim2  <- max(5, m * 3)
maxX1 <- m * 5
maxX2 <- maxX1 * 5

ints <- data.frame(left = d$nDist, right = d$nDist)
# Estimate negative binomial with leftmost part of the distribution
int1 <- ints
int1$left[d$nDist > lim1] <- lim1
int1$right[d$nDist > lim1] <- NA
df1 <- d[d$nDist <= lim1, ]
f1  <- fitdistrplus::fitdistcens(int1, "nbinom")
threshold1 <- qnbinom(opt$pvalue1, size = f1$estimate[["size"]], mu = f1$estimate[["mu"]])
threshold2 <- qnbinom(1 - opt$pvalue2, size = f1$estimate[["size"]], mu = f1$estimate[["mu"]])
print(f1)
print(threshold1)

# Estimate log normal with rightmost part of the distribution
int2 <- ints
int2$left[d$nDist <= lim2] <- NA
int2$right[d$nDist <= lim2] <- lim2
df2 <- d[d$nDist >= lim2 & d$nDist <= 5 * maxX1, ]
f2  <- fitdistrplus::fitdistcens(int2, "lnorm")
print(f2)
threshold2 <- qlnorm(1 - opt$pvalue2, meanlog = f2$estimate[["meanlog"]], sdlog = f2$estimate[["sdlog"]])
print(threshold2)

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
    ggplot2::stat_function(fun = dnbinom, n = maxX1 + 1, args = list(size = f1$estimate[["size"]], mu = f1$estimate[["mu"]]), linetype = "dotted", color = "darkgreen") +
    ggplot2::geom_vline(xintercept = m, linetype = "dotted") +
    ggplot2::geom_vline(xintercept = lim1, linetype = "dashed") +
    ggplot2::geom_vline(xintercept = threshold1, color = "darkred") +
    ggplot2::xlab("Edit distance") +
    ggplot2::xlim(0, maxX)
    ggplot2::ggsave(opt$plot1, p)
}

# Plot rightmost output
if (! is.null(opt$plot2)) {
  p <- ggplot2::ggplot(df2, ggplot2::aes(nDist)) + 
    ggplot2::geom_freqpoly(ggplot2::aes(y = ggplot2::after_stat(density)), binwidth = 1, color = "black") +
    ggplot2::stat_function(fun = dlnorm, n = maxX2 + 1 - lim2, args = list(meanlog = f2$estimate[["meanlog"]], sdlog = f2$estimate[["sdlog"]]), linetype = "dotted", color = "darkgreen") +
    ggplot2::geom_vline(xintercept = m, linetype = "dotted") +
    ggplot2::geom_vline(xintercept = lim2, linetype = "dashed") +
    ggplot2::geom_vline(xintercept = threshold2, color = "darkred") +
    ggplot2::xlab("Edit distance") +
    ggplot2::xlim(lim2, 5 * maxX)
    ggplot2::ggsave(opt$plot2, p)
}

q(status = 0)
