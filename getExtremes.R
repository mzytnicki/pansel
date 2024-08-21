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
input <- read.table("/Scratch/mazytnicki/PanSel/Results/MGC/10000/chr_all_hprc-v1.1-mc-chm13-full_GRCh38.0.chrall.bed", col.names = c("chr", "start", "end", "id", "index", "strand"))

# Transform to log, remove zeros (hopefully, few)
d <- input$index
d <- d[d > 0]
d <- -log(d)
d <- d[d > 0]

# Compute mode
m <- as.numeric(names(sort(-table(round(d, 4))))[1])
m1 <- 1.1 * m

# Estimate normal with leftmost part of the distribution
d1 <- d[d <= m1]
d2 <- 2 * m1 - d1
d1 <- c(d1, d2)
f1 <- MASS::fitdistr(d1, "normal")
threshold1 <- qnorm(opt$pvalue1, mean = f1$estimate[["mean"]], sd = f1$estimate[["sd"]])
print(f1)
print(exp(-threshold1))

# Estimate log normal with the whole distribution
f2 <- MASS::fitdistr(d, "lognormal")
threshold2 <- qlnorm(1 - opt$pvalue2, meanlog = f2$estimate[["meanlog"]], sdlog = f2$estimate[["sdlog"]])
print(f2)
print(exp(-threshold2))

maxX <- threshold2 * 1.2

# Print outliers (most conserved, least conserved) in BED format
if (! is.null(opt$output1)) {
  output1 <- input[input$index >= exp(-threshold1), ]
  write.table(output1, file = opt$output1, quote = FALSE, sep = "\t", col.names = FALSE, row.names = FALSE)
}
if (! is.null(opt$output2)) {
  output2 <- input[input$index <= exp(-threshold2), ]
  write.table(output2, file = opt$output2, quote = FALSE, sep = "\t", col.names = FALSE, row.names = FALSE)
}

# Plot
if (! is.null(opt$plot)) {
  f <- function(.x, mean, sd, meanlog, sdlog) {
    return((dnorm(.x, mean = mean, sd = sd) + dlnorm(.x, meanlog = meanlog, sdlog = sdlog)) / 2)
  }
  p <- ggplot2::ggplot(data.frame(data = d), ggplot2::aes(data)) +
    ggplot2::geom_freqpoly(ggplot2::aes(y = ggplot2::after_stat(density)), binwidth = 0.0001) +
    ggplot2::stat_function(fun = f, n = 10000, args = list(mean = f1$estimate[["mean"]], sd = f1$estimate[["sd"]], meanlog = f2$estimate[["meanlog"]], sdlog = f2$estimate[["sdlog"]]), color = "darkgreen", linetype = "dashed") +
    ggplot2::geom_vline(xintercept = threshold1, linetype = "dotted", color = "darkblue") +
    ggplot2::geom_vline(xintercept = threshold2, linetype = "dotted", color = "darkred") +
    ggplot2::xlab("Log Jaccard index") +
    ggplot2::xlim(0, maxX)
  ggplot2::ggsave(opt$plot, p)
}

q(status = 0)
