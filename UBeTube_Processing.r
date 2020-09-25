#-----------------------------------#
#### UBeTube Processing R Script ####
##   Script can be used to process UBeTube data. See UBeTube_Processing_Guide.pdf for detailed instructions.
##   By: Justin Johnson - University of Arizona
##   2020-09-21

# Load necessary packages

#install.packages(readxl)
#install.packages(tidyverse)
#install.packages(broom)
library(readxl)
library(tidyverse)
library(broom)

# Names of files to be imported and exported
calibrationfilename <- "calibration.xls"                  #Name of calibration dataset
timeeseriesfilename <- "example_dataset.xls"              #Name of time series dataset
ratingcurvefilename <- "ratingcurve.png"                  #Name of file calibration rating curve should be exported to
hydrographfilename <- "hydrograph.png"                    #Name of file hydrograph should be exported to

#Input values
h0 <- 35.7 #Height of bottom of slot relative to pressure transducer (cm)  
d <- 10.16 #Interior diameter of UBeTube (cm)

#---------------------------------------------------------------------------------#
# NO CHANGES NEEDED TO CODE BELOW UNLESS CUSTOMIZING CALIBRATIONS OR PLOT OUTPUTS #

##-----------------##
#### CALIBRATION ####
##-----------------##

#Read in calibration data
calibration <- read_excel("calibration_data.xls", 
                          sheet=1, 
                          skip=1,
                          col_types = c("numeric", "numeric", "numeric"), 
                          col_names=c("h0.mm", "hraw.mm", "Q.Lmin"))

#Converts height to cm from mm
calibration1 <- calibration %>%
  mutate(h.mm = hraw.mm-h0.mm,
         h.cm = h.mm/10)

#Runs power-law regression to predict discharge from stage.
ratingcurve.model <-nls(calibration1$Q.Lmin~a*calibration1$h.cm^b,
                        data=calibration1,
                        start=list(a=1,b=1))
ratingcurve.tidymodel <- tidy(ratingcurve.model)

#Extracts a and b estimates
a <- as.numeric(ratingcurve.tidymodel[1,2])
b <- as.numeric(ratingcurve.tidymodel[2,2])

#Creates label for plot with model results
label <- sprintf("Q == %.3g*h^%.3g", a, b)

#Plots rating curve
ratingcurve.plot <- ggplot(calibration1, aes(h.cm, Q.Lmin))+
  geom_point()+
  labs(x="h (cm)", 
       y=bquote('Q (L·'*min^-1*')'))+
  geom_smooth(method = 'nls', 
              formula = 'y~a*x^b', 
              method.args = list(start= c(a = 1,b=1)), 
              se=FALSE)+
  theme_classic()+
  annotate("text", 
           x=0.6*median(calibration1$h.cm, na.rm=TRUE), 
           y=median(calibration1$Q.Lmin, na.rm=TRUE), 
           label= label,
           color="blue",
           parse=TRUE)

#Saves rating curve
ggsave(ratingcurvefilename, 
       plot = ratingcurve.plot,
       width = 7,
       height = 7)

##-----------------##
#### TIME SERIES ####
##-----------------##

#Reads in time series dataset
UBeTube <- read_excel("example_dataset.xls", 
                      sheet=1, 
                      skip=3, 
                      col_types = c("date", "numeric", "skip", "skip"), 
                      col_names=c("time", "hraw.mm"))

#Wrangles time series data
UBeTube1 <- UBeTube %>%
  mutate(hraw.cm = hraw.mm/10, #Converts height to cm from mm
         time.sec = as.numeric(time, unit='sec'), #Converts time to seconds
         h.cm = hraw.cm-h0) #Determines height of water in UBeTube relative to h0

#Calculates outflow
UBeTube2 <- UBeTube1 %>%
  mutate(Q.Lmin=a*h.cm^b) #Calculates outflow based on Equation 1

#Calculates inflow
UBeTubeFinal <- UBeTube2 %>%
  mutate(S.cm3s = (pi*(d^2)*h.cm)/4, #Calculates volume of water stored in UBeTube
         S.Lmin = S.cm3s*60/1000, #Converts storage to L/min
         I.Lmin = (S.Lmin-lag(S.Lmin))/(time.sec-lag(time.sec))
         +((Q.Lmin+lag(Q.Lmin))/2)) #Calculates inflow using Equation 3

#Plots hydrograph
plot(UBeTubeFinal$time,UBeTubeFinal$I.Lmin, type="l", 
     xlab="Time (hh:mm)", 
     ylab= expression('Inflow (L·min' ^ {-1}*')'))

#Saves hydrograph
dev.copy(png,hydrographfilename,
         width=720,
         height=480) 
dev.off() 
