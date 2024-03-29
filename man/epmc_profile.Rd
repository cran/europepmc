% Generated by roxygen2: do not edit by hand
% Please edit documentation in R/epmc_profile.r
\name{epmc_profile}
\alias{epmc_profile}
\title{Obtain a summary of hit counts}
\usage{
epmc_profile(query = NULL, synonym = TRUE)
}
\arguments{
\item{query}{character, search query. For more information on how to
build a search query, see \url{https://europepmc.org/Help}}

\item{synonym}{logical, synonym search. If TRUE, synonym terms from MeSH
terminology and the UniProt synonym list are queried, too. Enabled by
default.}
}
\description{
This functions returns the number of results found for your query,
  and breaks it down to the various publication types, data sources, and
  subsets Europe PMC provides.
}
\examples{
\dontrun{
  epmc_profile('malaria')
  # use field search, e.g. query materials and reference section for
  # mentions of "ropensci"
  epmc_profile('(METHODS:"ropensci")')
 }
}
