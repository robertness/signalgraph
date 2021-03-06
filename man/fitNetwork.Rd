% Generated by roxygen2: do not edit by hand
% Please edit documentation in R/fitting.R
\name{fitNetwork}
\alias{fitNetwork}
\alias{fit_initialized_sg}
\title{Fit a Signalgraph model}
\usage{
fitNetwork(g, data, fixed = NULL, graph_attr = list(L2_pen = 0.04),
  min.iter = 2, max.iter = 5, epsilon = 1e-04, verbose = FALSE)

fit_initialized_sg(g, min.iter = 2, max.iter = 5, epsilon = 1e-04,
  verbose = FALSE)
}
\arguments{
\item{g}{igraph object. The vertices must be named.}

\item{data}{a data frame. All of the names in the data from must match a vertex name.}

\item{fixed}{names of fixed variables in the vertices}

\item{graph_attr}{list of graph attributes.  Graph attributes include:
\itemize{
 \item{L1_pen:}{ penalized least squares error L1 penalty parameter value}
 \item{L2_pen:}{ penalized least squares error L2 penalty parameter value. The default L2 penalty parameter is .04.}
 \item{activation:}{ the activation function (this actually is an R function), defaults to logistic.}
 \item{activation.prime:}{ The derivative fo the activation function, used in gradient calculation. Defaults to NULL}
 \item{min.max.constraints:}{ 2 element numeric containing the acceptable range for each rate.}
 }}

\item{min.iter}{minimum number of iterations}

\item{max.iter}{maximum number of iterations}

\item{epsilon}{after the minimum number of iterations, when change in means squared error 
between iterations falls below epsilon, cease optimizing and return current estimates}

\item{verbose}{if set to true, prints messages of details of optimization.}
}
\value{
A fitted signalgraph object.
}
\description{
fitNetwork initializes a graph into a signalgraph then fits the model with penalized least squares.
fit_initialized_sg fits an network already initialized by initializeGraph.  fit_initialized_sg
is called by fitNetwork.
}

