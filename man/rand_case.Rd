% Generated by roxygen2: do not edit by hand
% Please edit documentation in R/templates.R
\name{rand_case}
\alias{rand_case}
\title{Test Case: Random graph and matching data}
\usage{
rand_case(p, n = p * p + p, input_g = NULL, method = "ordered")
}
\arguments{
\item{p}{the number of desired nodes}

\item{n}{the number of desired rows in the data}

\item{input_g}{an igraph object.  If supplied then the graph is simulated from
a power law fit on this input graph.}

\item{method}{the fitting method for simulating a directed acyclic graph.  Ignored
if input_g is supplied.}
}
\value{
A list of two elements, graph and data.
}
\description{
Generates an igraph object and a corresponding dataset.  A number of unobserved vertices will 
be chosen at random.  Used to randomly generate test cases.  If supplied an input graph structure,
the new structure is simulated using a power law.  Otherwise, the function uses the sim_DAG in 
the lucy \url{https://github.com/robertness/lucy} package.
}
\seealso{
power_signal_graph

sim_DAG
}

