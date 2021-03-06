#===============
#AssignDrivers.R
#===============
# This module assigns drivers by age group to each household as a function of
# the numbers of persons and workers by age group, the household income, land
# use characteristics, and public transit availability.


#=================================
#Packages used in code development
#=================================
#Uncomment following lines during code development. Recomment when done.
# library(visioneval)


#=============================================
#SECTION 1: ESTIMATE AND SAVE MODEL PARAMETERS
#=============================================
#
#Define a function to estimate driver choice model
#-------------------------------------------------
#' Estimate housing choice model
#'
#' \code{estimateDriverModel} estimates a binomial logit model for choosing
#' between driver and non-driver
#'
#' This function estimates a binomial logit model for predicting whether a
#' person is a driver or a non-driver
#'
#' @param Data_df A data frame containing estimation data.
#' @param StartTerms_ A character vector of the terms of the model to be
#' tested in the model.
#' @param ValidationProp A numeric value between 0 and 0.5 which specified
#' the proportion of Data_df that will be the validation dataset. The remainder
#' will be the training dataset.
#' @return A list which has the following components:
#' Type: a string identifying the type of model ("binomial"),
#' Formula: a string representation of the model equation,
#' PrepFun: a function that prepares inputs to be applied in the binomial model,
#' OutFun: a function that transforms the result of applying the binomial model.
#' Summary: the summary of the binomial model estimation results.
#' Anova: the results of analysis of variance of the model.
#' PropCorrectlyPredicted: the proportion of validation set observed values that
#' are correctly predicted by the estimated. The model is estimated using 80% of
#' the data and validated using the remaining 20%. The proportion of correct
#' predictions for the validation data set is calculated.
#' @import visioneval stats
#Define function to estimate the income model
estimateDriverModel <- function(Data_df, StartTerms_, ValidationProp) {
  #Define function to prepare inputs for estimating model
  prepIndepVar <-
    function(In_df) {
      Out_df <- In_df
      Out_df$IncomeSq <- In_df$Income ^ 2
      Out_df$IsSF <- as.numeric(In_df$HouseType == "SF")
      Out_df$Age15to19 <- as.numeric(In_df$AgeGroup == "Age15to19")
      Out_df$Age20to29 <- as.numeric(In_df$AgeGroup == "Age20to29")
      Out_df$Age30to54 <- as.numeric(In_df$AgeGroup == "Age30to54")
      Out_df$Age55to64 <- as.numeric(In_df$AgeGroup == "Age55to64")
      Out_df$Age65Plus <- as.numeric(In_df$AgeGroup == "Age65Plus")
      Out_df$Intercept <- 1
      Out_df
    }
  EstData_df <- prepIndepVar(Data_df)
  #Define function to make the model formula
  makeFormula <-
    function(StartTerms_) {
      FormulaString <-
        paste("Driver ~ ", paste(StartTerms_, collapse = "+"))
      as.formula(FormulaString)
    }
  #Split data into training and validation data sets
  if (ValidationProp > 0.5) {
    stop("The proportion of the Data_df reserved for validation (ValidationProp) must be no greater than 0.5.")
  }
  NumCases <- nrow(EstData_df)
  ValidateIdx <- sample(1:NumCases, round(ValidationProp * NumCases))
  TrainIdx <- (1:NumCases)[!(1:NumCases %in% ValidateIdx)]
  #Estimate model
  DriverModel <-
    glm(makeFormula(StartTerms_), family = binomial, data = EstData_df[TrainIdx,])
  #Check validation
  PredProb_ <-
    predict(DriverModel, newdata = EstData_df[ValidateIdx,], type = "response")
  Pred_ <- ifelse(PredProb_ > 0.5, 1, 0)
  Obs_ <- EstData_df[ValidateIdx, "Driver"]
  Compare_tbl <- table(Obs_, Pred_)
  #Return model
  list(
    Type = "binomial",
    Formula = makeModelFormulaString(DriverModel),
    Choices = c(1, 0),
    PrepFun = prepIndepVar,
    Summary = summary(DriverModel),
    Anova = anova(DriverModel, test = "Chisq"),
    PropCorrectlyPredicted = sum(diag(Compare_tbl)) / sum(Compare_tbl)
  )
}

#Set up data estimate models
#---------------------------
#Load NHTS household data
Hh_df <- VE2001NHTS::Hh_df
#Identify records used for estimating metropolitan area models
Hh_df$IsMetro <- Hh_df$Msacat %in% c("1", "2")
#Load NHTS person data to use for model estimation
Per_df <- VE2001NHTS::Per_df[, c("Houseid", "Driver", "AgeGroup", "Worker")]
#Join person data with select household data
ModelVars_ <-
  c("Houseid", "Hbppopdn", "Income", "Hhsize", "Hometype", "UrbanDev",
    "BusEqRevMiPC", "Hhvehcnt", "IsMetro", "FwyLnMiPC")
D_df <- merge( Per_df, Hh_df[, ModelVars_], "Houseid")
#Define variables consistent with other module names
D_df$HouseType <- "MF"
D_df$HouseType[D_df$Hometype == "Single Family"] <- "SF"
D_df$HhSize <- D_df$Hhsize
D_df$PopDensity <- D_df$Hbppopdn
D_df$IsUrbanMixNbrhd <- D_df$UrbanDev
D_df$TranRevMiPC <- D_df$BusEqRevMiPC

#Estimate metropolitan and non-metropolitan driver models
#--------------------------------------------------------
#Estimate the metropolitan model
DriverModelTerms_ <-
  c(
    "Age15to19",
    "Age20to29",
    "Age30to54",
    "Age55to64",
    "Age65Plus",
    "Worker",
    "HhSize",
    "Income",
    "IncomeSq",
    "IsSF",
    "PopDensity",
    "IsUrbanMixNbrhd",
    "TranRevMiPC"
  )
MetroDriverModel_ls <-
  estimateDriverModel(
    Data_df = D_df[D_df$IsMetro,],
    StartTerms_ = DriverModelTerms_,
    ValidationProp = 0.2)
MetroDriverModel_ls$SearchRange <- c(-10, 10)
rm(DriverModelTerms_)
#Estimate the nonmetropolitan model
DriverModelTerms_ <-
  c(
    "Age15to19",
    "Age20to29",
    "Age30to54",
    "Age55to64",
    "Age65Plus",
    "Worker",
    "HhSize",
    "Income",
    "IncomeSq",
    "IsSF",
    "PopDensity"
  )
NonMetroDriverModel_ls <-
  estimateDriverModel(
    D_df[!D_df$IsMetro,],
    DriverModelTerms_,
    ValidationProp = 0.2)
NonMetroDriverModel_ls$SearchRange <- c(-10, 10)
rm(DriverModelTerms_)
#Combine the models
DriverModel_ls <- list(
  Metro = MetroDriverModel_ls,
  NonMetro = NonMetroDriverModel_ls
)

#Save the driver choice model
#----------------------------
#' Driver choice model
#'
#' A list containing the driver choice models for metropolitan and
#' non-metropolitan areas. Includes model equations and other information
#' needed to implement the driver choice model.
#'
#' @format A list having having Metro and NonMetro components, with each having the following components:
#' \describe{
#'   \item{Type}{a string identifying the type of model}
#'   \item{Formula}{a string representation of the model formula}
#'   \item{PrepFun}{a function that prepares inputs to be applied in the model}
#'   \item{Summary}{the summary of the binomial logit model estimation results}
#'   \item{Anova}{results of analysis of variance of the model}
#'   \item{PropCorrectlyPredicted}{proportion of cases of validation dataset correctly predicted by model}
#'   \item{SearchRange}{a two-element vector specifying the range of search values}
#' }
#' @source AssignDrivers.R script.
"DriverModel_ls"
devtools::use_data(DriverModel_ls, overwrite = TRUE)


#================================================
#SECTION 2: DEFINE THE MODULE DATA SPECIFICATIONS
#================================================

#Define the data specifications
#------------------------------
AssignDriversSpecifications <- list(
  #Level of geography module is applied at
  RunBy = "Region",
  #Specify new tables to be created by Inp if any
  #Specify new tables to be created by Set if any
  #Specify input data
  Inp = items(
    item(
      NAME =
        items(
          "Drv15to19AdjProp",
          "Drv20to29AdjProp",
          "Drv30to54AdjProp",
          "Drv55to64AdjProp",
          "Drv65PlusAdjProp"),
      FILE = "region_hh_driver_adjust_prop.csv",
      TABLE = "Region",
      GROUP = "Year",
      TYPE = "double",
      UNITS = "proportion",
      NAVALUE = -1,
      SIZE = 0,
      PROHIBIT = c("NA", "< 0"),
      ISELEMENTOF = "",
      UNLIKELY = c("> 1.5"),
      TOTAL = "",
      DESCRIPTION =
        items(
          "Target proportion of unadjusted model number of drivers 15 to 19 years old (1 = no adjustment)",
          "Target proportion of unadjusted model number of drivers 20 to 29 years old (1 = no adjustment)",
          "Target proportion of unadjusted model number of drivers 30 to 54 years old (1 = no adjustment)",
          "Target proportion of unadjusted model number of drivers 55 to 64 years old (1 = no adjustment)",
          "Target proportion of unadjusted model number of drivers 65 or older (1 = no adjustment)"
        ),
      OPTIONAL = TRUE
    )
  ),
  #Specify data to be loaded from data store
  Get = items(
    item(
      NAME =
        items(
          "Drv15to19AdjProp",
          "Drv20to29AdjProp",
          "Drv30to54AdjProp",
          "Drv55to64AdjProp",
          "Drv65PlusAdjProp"),
      TABLE = "Region",
      GROUP = "Year",
      TYPE = "double",
      UNITS = "proportion",
      PROHIBIT = c("NA", "< 0"),
      ISELEMENTOF = "",
      OPTIONAL = TRUE
    ),
    item(
      NAME = "Marea",
      TABLE = "Marea",
      GROUP = "Year",
      TYPE = "character",
      UNITS = "ID",
      PROHIBIT = "",
      ISELEMENTOF = ""
    ),
    item(
      NAME = "TranRevMiPC",
      TABLE = "Marea",
      GROUP = "Year",
      TYPE = "compound",
      UNITS = "MI/PRSN/YR",
      PROHIBIT = c("NA",  "< 0"),
      ISELEMENTOF = ""
    ),
    item(
      NAME = "Bzone",
      TABLE = "Bzone",
      GROUP = "Year",
      TYPE = "character",
      UNITS = "ID",
      PROHIBIT = "",
      ISELEMENTOF = ""
    ),
    item(
      NAME = "D1B",
      TABLE = "Bzone",
      GROUP = "Year",
      TYPE = "compound",
      UNITS = "PRSN/SQMI",
      PROHIBIT = c("NA",  "< 0"),
      ISELEMENTOF = ""
    ),
    item(
      NAME = "Marea",
      TABLE = "Household",
      GROUP = "Year",
      TYPE = "character",
      UNITS = "ID",
      PROHIBIT = "",
      ISELEMENTOF = ""
    ),
    item(
      NAME = "Bzone",
      TABLE = "Household",
      GROUP = "Year",
      TYPE = "character",
      UNITS = "ID",
      PROHIBIT = "",
      ISELEMENTOF = ""
    ),
    item(
      NAME = "HhId",
      TABLE = "Household",
      GROUP = "Year",
      TYPE = "character",
      UNITS = "ID",
      PROHIBIT = "",
      ISELEMENTOF = ""
    ),
    item(
      NAME =
        items("Age15to19",
              "Age20to29",
              "Age30to54",
              "Age55to64",
              "Age65Plus"),
      TABLE = "Household",
      GROUP = "Year",
      TYPE = "people",
      UNITS = "PRSN",
      PROHIBIT = c("NA", "< 0"),
      ISELEMENTOF = ""
    ),
    item(
      NAME =
        items("Wkr15to19",
              "Wkr20to29",
              "Wkr30to54",
              "Wkr55to64",
              "Wkr65Plus"),
      TABLE = "Household",
      GROUP = "Year",
      TYPE = "people",
      UNITS = "PRSN",
      PROHIBIT = c("NA", "< 0"),
      ISELEMENTOF = ""
    ),
    item(
      NAME = "Income",
      TABLE = "Household",
      GROUP = "Year",
      TYPE = "currency",
      UNITS = "USD.2001",
      PROHIBIT = c("NA", "< 0"),
      ISELEMENTOF = ""
    ),
    item(
      NAME = "HhSize",
      TABLE = "Household",
      GROUP = "Year",
      TYPE = "people",
      UNITS = "PRSN",
      PROHIBIT = c("NA", "<= 0"),
      ISELEMENTOF = ""
    ),
    item(
      NAME = "HouseType",
      TABLE = "Household",
      GROUP = "Year",
      TYPE = "character",
      UNITS = "category",
      PROHIBIT = "",
      ISELEMENTOF = c("SF", "MF", "GQ")
    ),
    item(
      NAME = "IsUrbanMixNbrhd",
      TABLE = "Household",
      GROUP = "Year",
      TYPE = "integer",
      UNITS = "binary",
      PROHIBIT = "NA",
      ISELEMENTOF = c(0, 1)
    ),
    item(
      NAME = "DevType",
      TABLE = "Household",
      GROUP = "Year",
      TYPE = "character",
      UNITS = "category",
      PROHIBITED = "NA",
      ISELEMENTOF = c("Urban", "Rural")
    )
  ),
  #Specify data to saved in the data store
  Set = items(
    item(
      NAME = items(
        "Drv15to19",
        "Drv20to29",
        "Drv30to54",
        "Drv55to64",
        "Drv65Plus"
      ),
      TABLE = "Household",
      GROUP = "Year",
      TYPE = "people",
      UNITS = "PRSN",
      NAVALUE = -1,
      PROHIBIT = c("NA", "< 0"),
      ISELEMENTOF = "",
      SIZE = 0,
      DESCRIPTION = items(
        "Number of drivers 15 to 19 years old",
        "Number of drivers 20 to 29 years old",
        "Number of drivers 30 to 54 years old",
        "Number of drivers 55 to 64 years old",
        "Number of drivers 65 or older")
    ),
    item(
      NAME = "Drivers",
      TABLE = "Household",
      GROUP = "Year",
      TYPE = "people",
      UNITS = "PRSN",
      NAVALUE = -1,
      PROHIBIT = c("NA", "< 0"),
      ISELEMENTOF = "",
      SIZE = 0,
      DESCRIPTION = "Number of drivers in household"
    )
  )
)

#Save the data specifications list
#---------------------------------
#' Specifications list for PredictHousing module
#'
#' A list containing specifications for the PredictHousing module.
#'
#' @format A list containing 4 components:
#' \describe{
#'  \item{RunBy}{the level of geography that the module is run at}
#'  \item{Inp}{scenario input data to be loaded into the datastore for this
#'  module}
#'  \item{Get}{module inputs to be read from the datastore}
#'  \item{Set}{module outputs to be written to the datastore}
#' }
#' @source AssignDrivers.R script.
"AssignDriversSpecifications"
devtools::use_data(AssignDriversSpecifications, overwrite = TRUE)


#=======================================================
#SECTION 3: DEFINE FUNCTIONS THAT IMPLEMENT THE SUBMODEL
#=======================================================
# The module assigns the number of drivers in each age group (except 0 - 14) to
# each household. It applies the driver model by age group and if the driver
# adjustment proportion for the age group is not 0, it calculates the modelled
# driver proportion and multiplies that by the adjustment proportion to get a
# new target proportion. It then adjusts the model until the adjusted target
# proportion is achieved. The purpose of the adjustment proportion is to account
# for trends in licensing among different age groups. For example, the rates of
# licensing of teenagers and young adults has fallen in recent years.

#Main module function that assigns drivers by age group to each household
#------------------------------------------------------------------------
#' Main module function to assign drivers by age group to each household.
#'
#' \code{AssignDrivers} assigns number of drivers by age group to each household.
#'
#' This function assigns the number of drivers in each age group to each
#' household. It also computes the total number of drivers in the household.
#'
#' @param L A list containing the components listed in the Get specifications
#' for the module.
#' @return A list containing the components specified in the Set
#' specifications for the module.
#' @import visioneval stats
#' @export
AssignDrivers <- function(L) {

  #Set up
  #------
  #Fix seed as synthesis involves sampling
  set.seed(L$G$Seed)
  #Initialize outputs list
  Bins_ <- c("15to19", "20to29", "30to54", "55to64", "65Plus")
  OutBinNames_ <- paste0("Drv", Bins_)
  NumHh <- length(L$Year$Household$HhId)
  Out_ls <- initDataList()
  for (OutName in OutBinNames_) {
    Out_ls$Year$Household[[OutName]] <- rep(0, NumHh)
  }
  #Identify vector of age and worker bins
  Bins_ <- c("15to19", "20to29", "30to54", "55to64", "65Plus")

  #Function to make a model dataset for an age bin
  #-----------------------------------------------
  makeModelDataset <- function(Bin) {
    # Make data frame for households that have persons in the age group
    Hh_df <- data.frame(
      HhId = L$Year$Household$HhId,
      Pop = L$Year$Household[[paste0("Age", Bin)]],
      Wkr = L$Year$Household[[paste0("Wkr", Bin)]],
      stringsAsFactors = FALSE
    )
    # Limit to households that have population in the age category
    Hh_df <- Hh_df[Hh_df$Pop != 0, ]
    # Initialize a person dataset to be used in estimating model
    Per_df <- data.frame(
      HhId = rep(Hh_df$HhId, Hh_df$Pop),
      stringsAsFactors = FALSE
    )
    # Add worker assignments
    assignWorkers <- function(Pop, Wkr) {
      c(rep(1, Wkr), rep(0, Pop - Wkr))
    }
    Per_df$Worker <- unlist(mapply(assignWorkers, Hh_df$Pop, Hh_df$Wkr))
    # Add age group
    Per_df$AgeGroup <- paste0("Age", Bin)
    # Add household attributes
    getHhAttribute <- function(AttrName) {
      L$Year$Household[[AttrName]][match(Per_df$HhId, L$Year$Household$HhId)]
    }
    AttrNames_ <-
      c("HhSize", "Income", "HouseType", "IsUrbanMixNbrhd", "DevType", "Bzone", "Marea")
    for (AttrName in AttrNames_) {
      Per_df[[AttrName]] <- getHhAttribute(AttrName)
    }
    # Add Bzone attributes
    Per_df$PopDensity <-
      L$Year$Bzone$D1B[match(Per_df$Bzone, L$Year$Bzone$Bzone)]
    # Add Marea attributes
    Per_df$TranRevMiPC <-
      L$Year$Marea$TranRevMiPC[match(Per_df$Marea, L$Year$Marea$Marea)]
    # Return the result
    Per_df
  }

  #Assign drivers to households by age bin
  #---------------------------------------
  for (Bin in Bins_) {
    BinName <- paste0("Drv", Bin)
    # Create model dataset for Bin
    Per_df <- makeModelDataset(Bin)
    # Get the driver age category adjustment prop
    if (!is.null(L$Year$Region[[paste0("Drv", Bin, "AdjProp")]])) {
      DrvAdjProp <- L$Year$Region[[paste0("Drv", Bin, "AdjProp")]]
    } else {
      DrvAdjProp <- 1
    }
    # Run metropolitan model
    MetroPer_df <- Per_df[Per_df$DevType == "Urban",]
    Driver_ <- applyBinomialModel(
      DriverModel_ls$Metro,
      MetroPer_df
    )
    if (DrvAdjProp != 1) {
      DriverProp <- DrvAdjProp * sum(Driver_) / length(Driver_)
      Driver_ <- applyBinomialModel(
        DriverModel_ls$Metro,
        MetroPer_df,
        TargetProp = DriverProp
      )
    }
    NumDrivers_Hh <- tapply(Driver_, MetroPer_df$HhId, sum)
    HhIdx <- match(names(NumDrivers_Hh), L$Year$Household$HhId)
    Out_ls$Year$Household[[BinName]][HhIdx] <- unname(NumDrivers_Hh)
    rm(MetroPer_df, Driver_, NumDrivers_Hh, HhIdx)
    # Run nonmetropolitan model
    NonMetroPer_df <- Per_df[Per_df$DevType != "Urban",]
    Driver_ <- applyBinomialModel(
      DriverModel_ls$NonMetro,
      NonMetroPer_df
    )
    if (DrvAdjProp != 1) {
      DriverProp <- DrvAdjProp * sum(Driver_) / length(Driver_)
      Driver_ <- applyBinomialModel(
        DriverModel_ls$NonMetro,
        NonMetroPer_df,
        TargetProp = DriverProp
      )
    }
    NumDrivers_Hh <- tapply(Driver_, NonMetroPer_df$HhId, sum)
    HhIdx <- match(names(NumDrivers_Hh), L$Year$Household$HhId)
    Out_ls$Year$Household[[BinName]][HhIdx] <- unname(NumDrivers_Hh)
    rm(NonMetroPer_df, Driver_, NumDrivers_Hh, HhIdx)
  }

  #Return list of results
  #----------------------
  #Calculate total number of drivers by household
  Drivers_ <- rowSums(do.call(cbind, Out_ls$Year$Household[OutBinNames_]))
  Out_ls$Year$Household$Drivers <- Drivers_
  Out_ls
}


#================================
#Code to aid development and test
#================================
#Test code to check specifications, loading inputs, and whether datastore
#contains data needed to run module. Return input list (L) to use for developing
#module functions
#-------------------------------------------------------------------------------
# TestDat_ <- testModule(
#   ModuleName = "AssignDrivers",
#   LoadDatastore = TRUE,
#   SaveDatastore = TRUE,
#   DoRun = FALSE
# )
# L <- TestDat_$L

#Test code to check everything including running the module and checking whether
#the outputs are consistent with the 'Set' specifications
#-------------------------------------------------------------------------------
# TestDat_ <- testModule(
#   ModuleName = "AssignDrivers",
#   LoadDatastore = TRUE,
#   SaveDatastore = TRUE,
#   DoRun = TRUE
# )
