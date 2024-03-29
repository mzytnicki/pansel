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
if (is.null(opt$binSize)) {
  stop("Missing bin size.")
}

# Parse input file
d <- read.table(opt$input, col.names = c("chr", "start", "end", "id", "distance", "strand"))
d$nDist <- as.integer(round(d$distance * opt$binSize))

# Compute mode
m <- as.numeric(names(which.max(as.list(table(d$nDist)))))

lim1  <- max(5, m * 2)
lim2  <- 0
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

# Estimate log normal with the positive part of distribution
f2 <- fitdistrplus::fitdist(d$nDist[d$nDist > 0], "lnorm")
print(f2)
threshold2 <- qlnorm(1 - opt$pvalue2, meanlog = f2$estimate[["meanlog"]], sdlog = f2$estimate[["sdlog"]])
print(threshold2)

df3 <- d[d$nDist <= maxX2, ]

# Print outliers (most conserved, least conserved) in BED format
if (! is.null(opt$output1)) {
  output1 <- d[d$nDist <= threshold1, ]
  write.table(output1, file = opt$output1, quote = FALSE, sep = "\t", col.names = FALSE, row.names = FALSE)
}
if (! is.null(opt$output2)) {
  output2 <- d[d$nDist >= threshold2, ]
  write.table(output2, file = opt$output2, quote = FALSE, sep = "\t", col.names = FALSE, row.names = FALSE)
}

# Plot
if (! is.null(opt$plot)) {
  f <- function(.x, size, mu, meanlog, sdlog) {
    return((dnbinom(round(.x), size = size, mu = mu) + dlnorm(.x, meanlog = meanlog, sdlog = sdlog)) / 2)
  }
  p <- ggplot2::ggplot(df3, ggplot2::aes(nDist)) + 
    ggplot2::geom_freqpoly(ggplot2::aes(y = ggplot2::after_stat(density)), binwidth = 1, color = "black") +
    ggplot2::stat_function(fun = f, n = maxX2 + 1, args = list(size = f1$estimate[["size"]], mu = f1$estimate[["mu"]], meanlog = f2$estimate[["meanlog"]], sdlog = f2$estimate[["sdlog"]]), linetype = "dashed", color = "darkgreen") +
    ggplot2::geom_vline(xintercept = threshold1, linetype = "dotted", color = "darkblue") +
    ggplot2::geom_vline(xintercept = threshold2, linetype = "dotted", color = "darkred") +
    ggplot2::xlab("Edit distance") +
    ggplot2::xlim(0, maxX2)
    ggplot2::ggsave(opt$plot, p)
}

q(status = 0)
