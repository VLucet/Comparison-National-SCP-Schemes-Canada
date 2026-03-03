## FUNCTIONS FOR TARGET PIPELINE

my_mean <- function(x) {
  x[is.na(x)] <- 0
  mean(x)
}