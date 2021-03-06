% Generated by roxygen2: do not edit by hand
% Please edit documentation in R/AssignVehicleFeatures.R
\name{apportionDvmt}
\alias{apportionDvmt}
\title{Assign VMT proportion to household vehicles.}
\usage{
apportionDvmt(Hh_df, DvmtProp = NULL)
}
\arguments{
\item{Hh_df}{A household data frame consisting of household characteristics.}

\item{DvmtProp}{A data frame of distribution of VMT proportion by number of
vehicles in a household.}
}
\value{
A list containing number of vehicles and ownership ratio for each household
}
\description{
\code{apportionDvmt} Assign VMT proportion to household vehicles.
}
\details{
This function assigns VMT proportions to household vehicles based on the
number of vehicles in the household and the probability distribution of proportion of
miles traveled by those vehicles.
}
