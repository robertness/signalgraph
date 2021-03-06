% Generated by roxygen2: do not edit by hand
% Please edit documentation in R/templates.R
\name{sim_system}
\alias{sim_system}
\title{Generate a random signalgraph object for data simulation}
\usage{
sim_system(p, n, input_g = NULL, method = "ordered", ...)
}
\arguments{
\item{p}{the number of desired nodes}

\item{n}{the number of desired rows in the data}

\item{input_g}{an igraph object.  If supplied then the graph is simulated from
a power law fit on this input graph.}

\item{method}{the fitting method for simulating a directed acyclic graph.  Ignored
if input_g is supplied.}

\item{...}{arguments past to fitNetwork, including graph attributes}
}
\value{
a signalgraph object
}
\description{
Produces a signalgraph objectwhere the values of the observed data and the fitted data are the same.  
This is designed to produce a gold standard, which can simulate data, where upon a new model can be 
fit on the simulated data, and the parameters of the standard and learned parameters of the new model
can be compared.
}
\seealso{
power_signal_graph

sim_DAG

rand_case
}

