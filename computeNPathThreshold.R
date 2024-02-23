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
#d$distance <- x
## Remove the highest 10% (probably outliers)
#l <- quantile(x, probs = 0.9)
#x <- x[x <= l[[1]]]
## Get the most populated 100-ile: will be the mean/median
#s <- seq(0, 1, 1/100) * max(x)
#q <- hist(x, breaks = s, plot = FALSE)
#c <- q$counts
#print(q)
#m <- which.max(c)
#message(print("max"))
#message(print(m))
#message(print(q$mids[[m]]))
#message(print(q$counts[[m]]))
#m <- q$mids[[m]]
## Mirror the values greater than the midpoint
#h <- x[x >= m]
#j <- -h + 2 * m
#h <- c(h, j)
## Compute the standard deviation
#s <- sd(j)
#print(s)

# Fit Gamma distribution, and find thresholds
# fitG <- fitdistrplus::fitdist(d$distance, "gamma")
# print(fitG)
# threshold <- qgamma(0.05, shape = fitG$estimate[["shape"]], rate = fitG$estimate[["rate"]])
# print(paste0("Estimated threshold: ", threshold))

# Fit NegativeBinomial distribution, and find thresholds
#fit <- fitdistrplus::fitdist(d$distance, "nbinom", method = "mme")
#fit <- MASS::fitdistr(d$distance, "nbinom")
#print(fit)
#threshold <- qnbinom(0.05, size = fit$estimate[["size"]], mu = fit$estimate[["mu"]])
#print(paste0("Estimated threshold: ", threshold))

# Learn censored exp-normal distribution
x <- d$distance
#x <- x[x > 0]
x <- exp(x)
d <- data.frame(distance = x)
l <- quantile(x, probs = c(0.01, 0.99))
print("here1")
print(head(x))
#fit <- fitdistrplus::fitdist(x, "norm")
print("here2")
#threshold <- qnorm(0.05, mean = fit$estimate[["mean"]], sd = fit$estimate[["sd"]])

# Plot distribution
p <- ggplot2::ggplot(d, ggplot2::aes(distance)) +
	ggplot2::geom_freqpoly(ggplot2::aes(y = ggplot2::after_stat(density)), binwidth = 1 / n, color = "black") +
	#ggplot2::geom_freqpoly(ggplot2::aes(y = ggplot2::after_stat(density)), binwidth = 1, color = "black") +
	#ggplot2::stat_function(fun = dnorm, n = n, args = list(mean = fit$estimate[["mean"]], sd = fit$estimate[["sd"]]), linetype = "dashed", color = "darkgray") +
	#ggplot2::stat_function(fun = dgamma, n = n, args = list(shape = fitG$estimate[["shape"]], rate = fitG$estimate[["rate"]]), linetype = "dashed", color = "darkgreen") +
	#ggplot2::stat_function(fun = dnbinom, n = (l+1), args = list(size = fit$estimate[["size"]], mu = fit$estimate[["mu"]]), linetype = "dashed", color = "darkgreen") +
	ggplot2::xlab("# paths") +
	ggplot2::ylab("Density") +
        ggplot2::xlim(l[[1]], l[[2]])# +
        #ggplot2::geom_vline(xintercept = threshold, linetype = "dashed", color = "darkgray")
ggplot2::ggsave(opt$output, p)
