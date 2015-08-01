% Generated by roxygen2 (4.1.1): do not edit by hand
% Please edit documentation in R/templates.R
\name{random_sg}
\alias{random_sg}
\title{Generate a random fitted signalgraph object}
\usage{
random_sg(m, n, max.iter = 1, no_fixed = FALSE, ...)
}
\arguments{
\item{m}{the number of desired nodes}

\item{n}{the number of desired rows in the data}

\item{no_fixed}{boolean if TRUE then all vertices are treated as random. Defaults to FALSE}

\item{...}{additional arguments, including graph attributes}
}
\value{
a signalgraph object
}
\description{
Uses the sim_DAG in the lucy \url{https://github.com/osazuwa223/lucy} package.
The vertices that must have data are the roots and the leaves, (everything in between can be hidden),
so data is simulated for only those nodes.
}
