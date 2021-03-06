% Generated by roxygen2: do not edit by hand
% Please edit documentation in R/CalculateHouseholdDvmt.R
\docType{data}
\name{DvmtModel_ls}
\alias{DvmtModel_ls}
\title{Daily vehicle miles traveled (DVMT) models}
\format{A list having 'Metro' and 'NonMetro' components. Each component has
the following components:
Pow: factor to untransform the results of the average DVMT model;
Ave: the formula for the average DVMT model;
Pctl85: the formula for the 85th percentile DVMT model;
Pctl95: the formula for the 95th percentile DVMT model;
Pctl99: the formula for the 99th percentile DVMT model;
Pctl100: the formula for the 100th percentile DVMT model.}
\source{
CalculateHouseholdDVMT.R
}
\usage{
DvmtModel_ls
}
\description{
A list of components used to predict the average and several pecentiles
(85th, 95th, 99th, 100th) of daily vehicle miles traveled for households.
The models are linear regression models. The average DVMT model predicts
average DVMT as a power transform. The 'Pow' component contains the power
term for untransforming the model results. The percentile DVMT models
predict the household DVMT at variou percentiles as a function of the
household's average DVMT.
}
\keyword{datasets}
