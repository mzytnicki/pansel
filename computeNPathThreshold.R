# Install packages if not present
#packageList <- c("fitdistrplus", "ggplot2", "getopt")
packageList <- c("MASS", "ggplot2", "getopt")
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
d <- read.table(opt$input, col.names = c("chr", "start", "end", "id", "distance", "strand"))
n <- 1000
x <- d$distance
r <- 1e-10
x <- (x - min(x) + r) / (max(x) - min(x) + 2 * r) # Rescale to avoid 0 and 1, not good for MLE

q <- quantile(d$distance, probs = 0.99)

# Fit Beta distribution, and find thresholds
#fitB <- fitdistrplus::fitdist(x, "beta")
#print(fitB)
#threshold <- qbeta(0.05, shape1 = fitB$estimate[["shape1"]], shape2 = fitB$estimate[["shape2"]])
#print(paste0("Estimated threshold: ", threshold))
#threshold <- qbeta(0.05, shape1 = fitB$estimate[["shape1"]], shape2 = fitB$estimate[["shape2"]])
#print(paste0("Estimated threshold: ", threshold))

fitC <-fitdistrplus::fitdist(x, "chisq", start = list(df = 0.1))
#fitC <- MASS::fitdistr(x, "chi-squared", start = list(df = 0.1), method = "BFGS")
print(fitC)
threshold <- qchisq(0.05, df = fitC$estimate[["df"]])
print(paste0("Estimated threshold: ", threshold))

# Plot distribution
p <- ggplot2::ggplot(d, ggplot2::aes(distance)) +
	ggplot2::geom_freqpoly(ggplot2::aes(y = ggplot2::after_stat(density)), binwidth = 1 / n, color = "black") +
	#ggplot2::stat_function(fun = dbeta, n = n, args = list(shape1 = fitB$estimate[["shape1"]], shape2 = fitB$estimate[["shape2"]]), linetype = "dashed", color = "darkgray") +
	ggplot2::xlab("# paths") +
	ggplot2::ylab("Density") +
        ggplot2::xlim(0, q) +
        ggplot2::geom_vline(xintercept = threshold, linetype = "dashed", color = "darkgray")
ggplot2::ggsave(opt$output, p)
