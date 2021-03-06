#import the dataset
library(readr)
led <- read_csv("LANGARA/DANA 4810/Group project/Life Expectancy Data.csv")
led <- Life.Expectancy.Data
#create descriptive statistics to look at missing values and means, medians, max min
summary (led)

str(led)

dim(led)

#installing pakage for deeper analysis of variables
install.packages("dlookr", dep = TRUE)

library(dlookr)

#diagnose the variables more deeply 
diagnose(led)

#pair plot


summary(led)


#diagnose the variables more deeply 
diagnose_category(led)

diagnose_numeric(led)

diagnose_outlier(led)



#create histoframs to look at the distrinution of numeric variables
hist(led$`Adult Mortality`)
hist(led$`Hepatitis B`)
hist(led$Polio)
hist(led$GDP)
hist(led$`Income composition of resources`)
hist(led$`infant deaths`)
hist(led$Measles)
hist(led$`Total expenditure`)
hist(led$Population)
hist(led$Schooling)
hist(led$Status)
hist(led$Alcohol)
hist(led$BMI)
hist(led$Diphtheria)
hist(led$`thinness  1-19 years`)
hist(led$`Life expectancy`)
hist(led$`percentage expenditure`)
hist(led$`under-five deaths`)
hist(led$`HIV/AIDS`)
hist(led$`thinness 5-9 years`)

#there are 10 missing values on the target variable, those were dropped

library(tidyr)
led.complete.target<- led %>% drop_na(Life.expectancy)

# fill the na values using the mice method of cart
library(mice)
md.pattern(led.complete.target)

imp <- mice(led.complete.target, method = "cart", m = 1)
summary(imp)
led.complete <- complete(imp)

#compare the mean and other variances between na data and without na data
summary(led.complete)
summary(led.complete.target)

#converting status factor into numeric by creating new column Status_1
led.complete$Status_1 <- ifelse(led.complete$Status=="Developed", 1, 0)


#split the dataset into training and testing 80:20

library(tidyverse)
library(caret)
library(caTools)
theme_set(theme_classic())


set.seed(142)
sample = sample.split(led.complete.target,SplitRatio = 0.8)
led.train =subset(led.complete.target,sample ==TRUE) 
led.test=subset(led.complete.target, sample==FALSE)

#to perform correlation on all numerical variables we need to drop 2 categorical columns, we also need to get rid of na values (deleted for now)

led.train.num = subset(led, select = -c(Country, Status))

led.num1<- led.train.num %>% drop_na()


#Correlation without dropping na values
install.packages("corrr")
library(corrr)
res.cor <- correlate(led.train.num)
res.cor

#Check Correlation of all columns with respect to life expectancy 
res.cor %>% 
  focus(Life.expectancy)

# for those who do not have the library install.packages("corrplot")
install.packages("corrplot")
library(corrplot)
corrplot(correlation, type = "upper", order = "hclust", 
         tl.col = "black", tl.srt = 45)



#--------- Cleaning Process------------
clean_LED <- subset(led, select = -c(infant.deaths,percentage.expenditure,Hepatitis.B,Measles,Total.expenditure,
                                     GDP,Population,thinness.5.9.years) )
summary(clean_LED)


library(tidyr)
clean_LED <- clean_LED %>% drop_na(Life.expectancy)


#======
#Cleaning Pipeline
#Drops all the columns that are not going to be used
drops<-c("Year","Status","infant deaths","percentage expenditure","Hepatitis B","under-five","HIV/AIDS","GDP","Population","thinness 5-9 years")
led_prep<-led[,!(names(led)%in%drops)]
led_prep[is.na(led_prep)]<-0
led_clean<-data.frame(Country=character(),
                      "Life.expectancy"=double(),
                      "Adult.Mortality"=double(),
                      "Alcohol"=double(),
                      "BMI"=double(),
                      "Polio"=double(),
                      "Diphteria"=double(),
                      "thinness.5-9.years"=double(),
                      "Income.composition.of.resources"=double(),
                      "Schooling"=double())
#Country vector
countries<-unique(led$Country)

#Imputation of missing values
for (country in countries){
  mask <- led_prep %>% filter(Country==country)
  #Mice goes here drop NA as placeholder
  imp <- mice(mask, method = "cart", m = 1,ignore=NULL)
  clean_mask<-complete(imp)
  print(clean_mask)
  #clean_mask<-drop_na(mask)
  #Mice goes here drop NA as placeholder
  imp <- mice(mask, method = "cart", m = 1,ignore=NULL)
  clean_mask<-complete(imp)
  #Append dataframes
  led_clean<-rbind(led_clean,clean_mask)
  
}

summary(led_clean)


#new Outlier treatment
num_clean <- led_clean[,-c(1,2,3)]
install.packages('psych')
library(psych)
clean_led1 <- winsor(num_clean, trim = 0.2, na.rm = FALSE)
final_clean.LED <- cbind(led_clean[,c(1:3)],clean_led1 )


summary(clean_led1)
summary(final_clean.LED)
plot(final_clean.LED)

#Outlier Treatment 
capOutlier <- function(x){
  qnt <- quantile(x, probs=c(.25, .75), na.rm = T)
  caps <- quantile(x, probs=c(.05, .95), na.rm = T)
  H <- 1.5 * IQR(x, na.rm = T)
  x[x < (qnt[1] - H)] <- caps[1]
  x[x > (qnt[2] + H)] <- caps[2]
  print(x)
  return(x)
}
ColumnNames<-colnames(led_clean)
ColumnNames=ColumnNames[ColumnNames!="Country"]
led_clean$Life.expectancy<-capOutlier(led_clean$Life.expectancy)
print(capOutlier(led_clean$Life.expectancy))
print(length(capOutlier(led_clean$Life.expectancy)))
for(column in ColumnNames){
  print(column)
  print(capOutlier(led_clean$column))
  #led_clean$column<-capOutlier(led_clean$column)
}





#building base model

set.seed(142)
sample = sample.split(final_clean.LED,SplitRatio = 0.8)
led.train =subset(final_clean.LED,sample ==TRUE) 
led.test=subset(final_clean.LED, sample==FALSE)



basic.model <- lm(Life.expectancy ~ Adult.Mortality+infant.deaths+Alcohol+percentage.expenditure+Hepatitis.B+
                    Measles+BMI+under.five.deaths+Polio+Total.expenditure+Diphtheria+HIV.AIDS+thinness..1.19.years+
                    Income.composition.of.resources+Schooling, data =final_clean.LED )


summary(basic.model)
library(olsrr)
library(tidyverse)#for easy data manipulation and visualization

library(broom)

pred.1 <-  predict(basic.model, led.test)
data.frame(
  RMSE = RMSE(pred.1, led.test$Life.expectancy),
  R2 = R2(pred.1, led.test$Life.expectancy),
  MAE= MAE(pred.1, led.test$Life.expectancy)
)

library(modelr)
data.frame(
  R2 = rsquare(basic.model, data = led.train),
  RMSE = rmse(basic.model, data = led.train),
  MAE = mae(basic.model, data = led.train)
)
ols_vif_tol(basic.model)
