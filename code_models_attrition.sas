proc phreg data=work.Projekt_full_clean plots(overlay=individual)=roc rocoptions(at= 10 20 30 40);
class  BusinessTravel Department JobInvolvement JobLevel JobSatisfaction OverTime StockOptionLevel TrainingTimesLastYear
          Age_segment Income_segment Distance_segment Companies_segment;
model YearsAtCompany*Attrition(0)=BusinessTravel Department JobInvolvement JobLevel JobSatisfaction OverTime StockOptionLevel
          TrainingTimesLastYear Age_segment Income_segment Distance_segment Companies_segment /ties=efron;
run;
proc import datafile='C:\Users\ola\Documents\sgh_master\sem2\analiza trwania czasu\PROJEKT\dataset_final.xlsx'
	dbms=xlsx
	out=WORK.PROJEKT_FULL
	replace;
	sheet='Sheet1';
run;

data work.projekt_full_clean;
    set work.projekt_full(drop=Age MonthlyIncome Date_of_Hire Age_group Income_group Distance_group Companies_group SalaryHike_group Promotion_group PercentSalaryHike YearsSinceLastPromotion NumCompaniesWorked DistanceFromHome);
run;

/*korelacje vramer*/
proc freq data=work.projekt_full;
    tables YearsAtCompany *TotalWorkingYears / chisq;
run;

/*-- ³acznie w kategorie */
proc freq data=work.projekt_full;
table TotalWorkingYears;
run;
proc format;
    value totalwork_fmt
        low -< 5  = '0-5'
        5 -< 10    = '5-10'
        10 -< 20   = '10-20'
        20 - high = '20+';
run;
data work.projekt_full_clean;
    set work.projekt_full_clean;
    TotalWork_Group = put(TotalWorkingYears, totalwork_fmt.);
run;

proc freq data=work.projekt_full_clean;
    tables TotalWork_Group *YearsAtCompany / chisq;
run;
/*-*/
proc freq data=work.projekt_full;
table YearsWithCurrManager;
run;
proc freq data=work.projekt_full;
    tables YearsWithCurrManager  *Age_segment / chisq;
run;
proc format;
    value YearsWithCurrManager_fmt
        low -< 1  = '0'
        1 -< 5    = '1-5'
        5 -< 10   = '5-10'
        10 - high = '10+';
run;
data work.projekt_full_clean;
    set work.projekt_full_clean;
    YearsWithCurrManager_Group = put(YearsWithCurrManager, YearsWithCurrManager_fmt.);
run;

proc freq data=work.projekt_full_clean;
    tables YearsWithCurrManager_Group *YearsAtCompany / chisq;
run;

/*usuniecie zmiennych z wysoka korelacj¹*/
data work.projekt_full_clean;
    set work.projekt_full_clean(drop= YearsWithCurrManager_Group YearsWithCurrManager TotalWork_Group TotalWorkingYears);
run;

/*data work.projekt_full_clean;
    set work.projekt_full_clean(drop= YearsWithCurrManager_Group YearsWithCurrManager);
run;8/

/* t - YearsAtCompany 
c - Attrition
Attrition(0) - pozostali
covid - 0 to nie zmarli*/ 

/*--------------------------*/
/*modele nieparametryczne*/
/*tablice trwania ¿ycia - kod pocztakowy, warto inne zmienne*/
/* - model tradyczyjny */
ods pdf file="lifetest_overall_lt.pdf" notoc style=journal;

proc lifetest 
    data=work.projekt_full_clean 
    method=lt 
    plots=(s h p);
    time YearsAtCompany*Attrition(0);
    title "LIFETEST - Ogólny wynik (metoda LT)";
run;

ods pdf close;

/* Krok 1: Tworzymy zbiór zmiennych z PROC CONTENTS */
proc contents data=work.projekt_full_clean out=work.Contents(keep=name) noprint;
run;

/* Krok 2: Tworzymy makrozmienn¹ z nazwami zmiennych */
proc sql noprint;
    select name
    into :strata_vars separated by ' '
    from work.Contents
	where name not in ('YearsAtCompany', 'Attrition');
quit;


/* Krok 3: Makro lifetest dla ka¿dej zmiennej */
%macro lifetest_by_strata;
    %let i = 1;
    %let var = %scan(&strata_vars, &i);

    %do %while(&var ne);

        ods pdf file="&var._lifetest_lt.pdf" notoc style=journal;

        proc lifetest data=work.projekt_full_clean method=lt plots=(s h p);
            time YearsAtCompany*Attrition(0);
            strata &var;
            title "Stratyfikacja wed³ug &var (metoda LT)";
        run;

        ods pdf close;

        %let i = %eval(&i + 1);
        %let var = %scan(&strata_vars, &i);
    %end;
%mend;

%lifetest_by_strata;


/* - metoda  Kaplana-Meiera*/
ods pdf file="lifetest_overall_pl.pdf" notoc style=journal;

proc lifetest 
    data=work.projekt_full_clean
    method=pl 
    plots=(s h p);
    time YearsAtCompany*Attrition(0);
    title "LIFETEST - Ogólny wynik (metoda PL)";
run;

ods pdf close;


%macro lifetest_by_strata_pl;
    %let i = 1;
    %let var = %scan(&strata_vars, &i);

    %do %while(&var ne);

        ods pdf file="&var._lifetest_pl.pdf" notoc style=journal;

        proc lifetest data=work.projekt_full_clean method=pl plots=(s h p);
            time YearsAtCompany*Attrition(0);
            strata &var;
            title "Stratyfikacja wed³ug &var";
        run;

        ods pdf close;

        %let i = %eval(&i + 1);
        %let var = %scan(&strata_vars, &i);
    %end;
%mend;

%lifetest_by_strata_pl;


/*--------------------------*/
/*modele parametryczne*/
/*podjscie klasyczne tylko*/
/*Modele proporcjonalnych hazardów*/
/* - model wyk³adniczy*/
ods pdf file="lifereg_models_exponential.pdf" notoc style=journal;

title "Model 1: Wyk³adniczy bez predyktorów – model w³aœciwy wg testu";
proc lifereg data=work.projekt_full_clean;
    model YearsAtCompany*Attrition(0) = / dist=exponential;
run;

title "Model 2: Wszystkie predyktory – lepszy AIC, ale nie w³aœciwy model";
proc lifereg data=work.projekt_full_clean;
    class BusinessTravel Department Gender JobInvolvement JobLevel JobSatisfaction MaritalStatus OverTime PerformanceRating 
          StockOptionLevel TrainingTimesLastYear Higher_Education Status_of_leaving Mode_of_work Leaves Absenteeism Work_accident 
          Source_of_Hire Age_segment Income_segment Distance_segment Companies_segment SalaryHike_segment Promotion_segment;
    model YearsAtCompany*Attrition(0) = BusinessTravel Department Gender JobInvolvement JobLevel JobSatisfaction MaritalStatus 
          OverTime PerformanceRating StockOptionLevel TrainingTimesLastYear Higher_Education Status_of_leaving Mode_of_work 
          Leaves Absenteeism Work_accident Source_of_Hire Age_segment Income_segment Distance_segment Companies_segment 
          SalaryHike_segment Promotion_segment / dist=exponential;
run;

title "Model 3: Istotne predyktory – model uproszczony, oparty na wyk³adniczym";
proc lifereg data=work.projekt_full_clean;
    class BusinessTravel Department JobInvolvement JobLevel JobSatisfaction OverTime StockOptionLevel 
          TrainingTimesLastYear Age_segment Distance_segment Companies_segment Promotion_segment;
    model YearsAtCompany*Attrition(0) = BusinessTravel Department JobInvolvement JobLevel JobSatisfaction OverTime StockOptionLevel 
          TrainingTimesLastYear Age_segment Distance_segment Companies_segment Promotion_segment / dist=exponential;
run;

ods pdf close;

/* - model weibulla*/
ods pdf file="lifereg_models_weibull.pdf" notoc style=journal;

title "Model 1: Weibull bez predyktorów";
proc lifereg data=work.projekt_full_clean;
    model YearsAtCompany*Attrition(0) = / dist=weibull;
run;

title "Model 2: Wszystkie predyktory (pe³ny model) – lepszy";
proc lifereg data=work.projekt_full_clean;
    class BusinessTravel Department Gender JobInvolvement JobLevel JobSatisfaction MaritalStatus OverTime PerformanceRating 
          StockOptionLevel TrainingTimesLastYear Higher_Education Status_of_leaving Mode_of_work Leaves Absenteeism Work_accident 
          Source_of_Hire Age_segment Income_segment Distance_segment Companies_segment SalaryHike_segment Promotion_segment;
    model YearsAtCompany*Attrition(0) = BusinessTravel Department Gender JobInvolvement JobLevel JobSatisfaction MaritalStatus 
          OverTime PerformanceRating StockOptionLevel TrainingTimesLastYear Higher_Education Status_of_leaving Mode_of_work 
          Leaves Absenteeism Work_accident Source_of_Hire Age_segment Income_segment Distance_segment Companies_segment 
          SalaryHike_segment Promotion_segment / dist=weibull;
run;

title "Model 3: Tylko istotne predyktory – uproszczony model";
proc lifereg data=work.projekt_full_clean;
    class BusinessTravel Department JobInvolvement JobLevel JobSatisfaction OverTime Income_segment  
          TrainingTimesLastYear Age_segment Distance_segment Companies_segment Promotion_segment;
    model YearsAtCompany*Attrition(0) = BusinessTravel Department JobInvolvement JobLevel JobSatisfaction OverTime Income_segment 
          TrainingTimesLastYear Age_segment Distance_segment Companies_segment Promotion_segment / dist=weibull;
run;

ods pdf close;

/* - model gamma*/
ods pdf file="lifereg_model_gamma.pdf" notoc style=journal;

title "Model Gamma – Brak zbie¿noœci (nieinteresuj¹cy)";
proc lifereg data=work.projekt_full_clean;
    model YearsAtCompany*Attrition(0)= /dist=gamma;
run;

ods pdf close;


/*Modele przyspieszonej pora¿ki*/
/* - modelu log-logistycznego*/
ods pdf file="lifereg_models_llogistic.pdf" notoc style=journal;

title "Model 1: Log-logistyczny bez predyktorów";
proc lifereg data=work.projekt_full_clean;
    model YearsAtCompany*Attrition(0) = / dist=llogistic;
run;

title "Model 2: Wszystkie predyktory (pe³ny model)";
proc lifereg data=work.projekt_full_clean;
    class BusinessTravel Department Gender JobInvolvement JobLevel JobSatisfaction MaritalStatus OverTime PerformanceRating 
          StockOptionLevel TrainingTimesLastYear Higher_Education Status_of_leaving Mode_of_work Leaves Absenteeism Work_accident 
          Source_of_Hire Age_segment Income_segment Distance_segment Companies_segment SalaryHike_segment Promotion_segment;
    model YearsAtCompany*Attrition(0) = BusinessTravel Department Gender JobInvolvement JobLevel JobSatisfaction MaritalStatus OverTime 
          PerformanceRating StockOptionLevel TrainingTimesLastYear Higher_Education Status_of_leaving Mode_of_work Leaves 
          Absenteeism Work_accident Source_of_Hire Age_segment Income_segment Distance_segment Companies_segment 
          SalaryHike_segment Promotion_segment / dist=llogistic;
run;

title "Model 3: Tylko istotne predyktory (model zoptymalizowany)";
proc lifereg data=work.projekt_full_clean;
    class BusinessTravel Department Gender JobInvolvement JobLevel JobSatisfaction OverTime StockOptionLevel 
          TrainingTimesLastYear Mode_of_work Leaves Age_segment Income_segment Distance_segment Companies_segment Promotion_segment;
    model YearsAtCompany*Attrition(0) = BusinessTravel Department Gender JobInvolvement JobLevel JobSatisfaction OverTime 
          StockOptionLevel TrainingTimesLastYear Mode_of_work Leaves Age_segment Income_segment Distance_segment Companies_segment 
          Promotion_segment / dist=llogistic;
run;

ods pdf close;

/* - modelu logarytmiczno-normalnego*/
ods pdf file="lifereg_models_ln.pdf" notoc style=journal;

title "Model 1: Logarytmiczno-normalny bez predyktorów";
proc lifereg data=work.projekt_full_clean;
    model YearsAtCompany*Attrition(0) = / dist=lnormal;
run;

title "Model 2: Wszystkie predyktory (pe³ny model)";
proc lifereg data=work.projekt_full_clean;
    class BusinessTravel Department Gender JobInvolvement JobLevel JobSatisfaction MaritalStatus OverTime PerformanceRating 
          StockOptionLevel TrainingTimesLastYear Higher_Education Status_of_leaving Mode_of_work Leaves Absenteeism Work_accident 
          Source_of_Hire Age_segment Income_segment Distance_segment Companies_segment SalaryHike_segment Promotion_segment;
    model YearsAtCompany*Attrition(0) = BusinessTravel Department Gender JobInvolvement JobLevel JobSatisfaction MaritalStatus OverTime 
          PerformanceRating StockOptionLevel TrainingTimesLastYear Higher_Education Status_of_leaving Mode_of_work Leaves 
          Absenteeism Work_accident Source_of_Hire Age_segment Income_segment Distance_segment Companies_segment 
          SalaryHike_segment Promotion_segment / dist=lnormal;
run;

title "Model 3: Tylko istotne predyktory (model zoptymalizowany)";
proc lifereg data=work.projekt_full_clean;
    class BusinessTravel Department Gender JobInvolvement JobLevel JobSatisfaction OverTime StockOptionLevel 
          Higher_Education Mode_of_work Leaves Age_segment Income_segment Distance_segment Companies_segment Promotion_segment;
    model YearsAtCompany*Attrition(0) = BusinessTravel Department Gender JobInvolvement JobLevel JobSatisfaction OverTime 
          StockOptionLevel Higher_Education Mode_of_work Leaves Age_segment Income_segment Distance_segment Companies_segment 
          Promotion_segment / dist=lnormal;
run;

ods pdf close;

/*Predykcja z wykorzystaniem modeli parametrycznych*/
%macro predict (zb_wyn=, outest=, out=_last_, xbeta=, time=);
 data &zb_wyn;
 _p_=1;
 set &outest point=_p_;
 set &out;
 lp=&xbeta;
 t=&time;
 gamma=1/_scale_;
 alpha=exp(-lp*gamma);
 prob=0;
 _dist_=upcase(_dist_);
 if _dist_='WEIBULL' or _dist_='EXPONENTIAL' or _dist_='EXPONENT' then prob=exp(-alpha*t**gamma);
 if _dist_='LOGNORMAL' or _dist_='LNORMAL' then prob=1-probnorm((log(t)-lp)/_scale_);
  if _dist_='LLOGISTIC' or _dist_='LLOGISTC' then prob=1/(1+alpha*t**gamma);
 if _dist_='GAMMA' then do;
 d=_shape1_;
 k=1/(d*d);
 u=(t*exp(-lp))**gamma;
 prob=1-probgam(k*u**d,k);
 if d lt 0 then prob=1-prob;
 end;
 drop lp gamma alpha _dist_ _scale_ intercept
 _shape1_ _model_ _name_ _type_ _status_ _prob_ _lnlike_ d k u;
 run;
 /*proc print data=_pred_;*/
 /*run;*/
 %mend predict;

proc lifereg data=work.projekt_full_clean outest=a;
    class BusinessTravel Department Gender JobInvolvement JobLevel JobSatisfaction OverTime StockOptionLevel 
          TrainingTimesLastYear Mode_of_work Leaves Age_segment Income_segment Distance_segment Companies_segment Promotion_segment;
    model YearsAtCompany*Attrition(0) = BusinessTravel Department Gender JobInvolvement JobLevel JobSatisfaction OverTime 
          StockOptionLevel TrainingTimesLastYear Mode_of_work Leaves Age_segment Income_segment Distance_segment Companies_segment 
          Promotion_segment / dist=llogistic;
	output OUT=b xbeta=lp;
run;

 %predict (zb_wyn=projekt_full_clean_pred50, outest=a, out=b, xbeta=lp, time=50);
 %predict (zb_wyn=projekt_full_clean_pred100, outest=a, out=b, xbeta=lp, time=100);
 %predict (zb_wyn=projekt_full_clean_pred150, outest=a, out=b, xbeta=lp, time=150);
 %predict (zb_wyn=projekt_full_clean_pred200, outest=a, out=b, xbeta=lp, time=200);

/*--------------------------*/
/*modele semiparametryczne*/

/*klasyczne podejscie*/
/* Metoda Breslowa - malo zdarzen powiazanych czyli takich, które zasz³y w tym samym momencie
jesli duzo to Efrona*/
proc sql;
  select YearsAtCompany, count(*) as liczba_osob
  from work.Projekt_full_clean
  where Status_of_leaving = 1
  group by YearsAtCompany
  having count(*) > 1
  order by liczba_osob desc;
quit;
/*duzo powiazan - Liczba obserwacji, które maj¹ identyczny czas wyst¹pienia zdarzenia 
— czyli ilu pracowników odesz³o z pracy po tylu samych latach zatrudnienia*/

proc phreg data=work.Projekt_full_clean;
class Gender;
model YearsAtCompany*Attrition(0)= Gender / ties=Efron;
run;

proc phreg data=work.Projekt_full;
class BusinessTravel Department Gender JobInvolvement JobLevel JobSatisfaction MaritalStatus OverTime PerformanceRating 
          StockOptionLevel TrainingTimesLastYear Higher_Education Status_of_leaving Mode_of_work Leaves Absenteeism Work_accident 
          Source_of_Hire Age_segment Income_segment Distance_segment Companies_segment SalaryHike_segment Promotion_segment;
model YearsAtCompany*Attrition(0)=BusinessTravel Department Gender JobInvolvement JobLevel JobSatisfaction MaritalStatus OverTime PerformanceRating 
          StockOptionLevel TrainingTimesLastYear Higher_Education Status_of_leaving Mode_of_work Leaves Absenteeism Work_accident 
          Source_of_Hire Age_segment Income_segment Distance_segment Companies_segment SalaryHike_segment Promotion_segment
/ties=efron selection=stepwise ;
run;

proc phreg data=work.Projekt_full;
class  BusinessTravel Department JobInvolvement JobLevel JobSatisfaction OverTime StockOptionLevel TrainingTimesLastYear 
          Age_segment Distance_segment Companies_segment  Promotion_segment;
model YearsAtCompany*Attrition(0)=BusinessTravel Department JobInvolvement JobLevel JobSatisfaction OverTime StockOptionLevel 
          TrainingTimesLastYear Age_segment Distance_segment Companies_segment  Promotion_segment
/ties=efron;
run;
/*Weryfikacja za³o¿enia proporcjonalnych hazardów – metoda graficzna - nie spe³nione za³o¿enie*/

/* Definicja symboli do 5 poziomów */
symbol1 i=join color=blue    line=1 value=none;
symbol2 i=join color=red     line=2 value=none;
symbol3 i=join color=green   line=3 value=none;
symbol4 i=join color=orange  line=4 value=none;
symbol5 i=join color=purple  line=5 value=none;
symbol6 i=join color=black   line=6 value=none;

%macro loglog_phreg_gplot(data=, time=YearsAtCompany, censor=Attrition, varlist=);

    %let i=1;
    %let var=%scan(&varlist, &i);

    %do %while(%length(&var) > 0);
        
        title "log(-log(S(t))) dla zmiennej &var";

        /* PHREG z wykresem log(-log S(t)) */
        proc phreg data=&data;
            model &time*&censor(0) = &var / ties=efron;
            strata &var;
            baseline out=zb_lls_&var loglogs=lls / method=pl;
        run;

        /* Wykres */
        proc gplot data=zb_lls_&var;
            plot lls*&time=&var;
        run;
        quit;

        %let i = %eval(&i + 1);
        %let var = %scan(&varlist, &i);
    %end;

%mend;

%loglog_phreg_gplot(
    data=work.Projekt_full_clean,
    varlist=BusinessTravel Department JobInvolvement JobLevel JobSatisfaction OverTime StockOptionLevel 
             TrainingTimesLastYear Age_segment Distance_segment Companies_segment Promotion_segment
);


/*Weryfikacja za³o¿enia proporcjonalnych hazardów – zmienne zale¿ne od czasu - spe³nione za³o¿enie*/
ods pdf file="C:\Users\ola\Documents\sgh_master\sem2\analiza trwania czasu\PROJEKT\1.pdf" style=journal;

proc phreg data=work.Projekt_full;
    model YearsAtCompany*Attrition(0) =
        BusinessTravel Department JobInvolvement JobLevel JobSatisfaction OverTime 
        StockOptionLevel TrainingTimesLastYear Age_segment Distance_segment 
        Companies_segment Promotion_segment

        BusinessTravel_t Department_t JobInvolvement_t JobLevel_t JobSatisfaction_t OverTime_t 
        StockOptionLevel_t TrainingTimesLastYear_t Age_segment_t Distance_segment_t 
        Companies_segment_t Promotion_segment_t
    / ties=efron;

    /* Interakcje zmiennych z czasem */
    BusinessTravel_t = BusinessTravel * YearsAtCompany;
    Department_t = Department * YearsAtCompany;
    JobInvolvement_t = JobInvolvement * YearsAtCompany;
    JobLevel_t = JobLevel * YearsAtCompany;
    JobSatisfaction_t = JobSatisfaction * YearsAtCompany;
    OverTime_t = OverTime * YearsAtCompany;
    StockOptionLevel_t = StockOptionLevel * YearsAtCompany;
    TrainingTimesLastYear_t = TrainingTimesLastYear * YearsAtCompany;
    Age_segment_t = Age_segment * YearsAtCompany;
    Distance_segment_t = Distance_segment * YearsAtCompany;
    Companies_segment_t = Companies_segment * YearsAtCompany;
    Promotion_segment_t = Promotion_segment * YearsAtCompany;
run;

ods pdf close;


/*Weryfikacja za³o¿enia proporcjonalnych hazardów – reszty Schoenfelda - spe³nione dla wszystkich zmiennych 
oprócz 1 zmiennej: Promotion_segment*/
%let vars = BusinessTravel Department JobInvolvement JobLevel JobSatisfaction OverTime 
            StockOptionLevel TrainingTimesLastYear Age_segment Distance_segment 
            Companies_segment Promotion_segment;

%macro schoenfeld_all;

    %let i = 1;
    %let var = %scan(&vars, &i);

    %do %while(%length(&var));

        /* Model Coxa i reszty Schoenfelda */
        proc phreg data=work.Projekt_full;
            class &var;
            model YearsAtCompany*Attrition(0) = &var / ties=efron;
            output out=R_Sch_&var (keep=YearsAtCompany &var &var._RS) 
                ressch = &var._RS;
            title "Cox: &var";
        run;

        /* Przygotowanie wykresu */
        goptions reset=all;
        goptions htext=1.5;
        axis1 order=(-1 0 1)
              label=(angle=90 'Schoenfeld residuals');
        axis2 label=('YearsAtCompany');
        symbol1 v=point i=sm90s width=1 c=blue;

        proc gplot data=R_Sch_&var;
            plot &var._RS*YearsAtCompany / vaxis=axis1 haxis=axis2;
            title "Schoenfeld residuals dla zmiennej: &var";
        run;

        /* Korelacja reszt z czasem */
        data R_Sch_&var._Ft;
            set R_Sch_&var;
            lt = log(YearsAtCompany);
            t2 = YearsAtCompany**2;
        run;

        proc corr data=R_Sch_&var._Ft;
            var YearsAtCompany lt t2 &var._RS;
            title "Korelacja czas-reszty dla: &var";
        run;

        %let i = %eval(&i + 1);
        %let var = %scan(&vars, &i);

    %end;

%mend;

%schoenfeld_all;

title;


/*Weryfikacja modelu – analiza reszt martynga³owych i reszt odchylenia*/
proc phreg data=work.Projekt_full_clean;
class  BusinessTravel Department JobInvolvement JobLevel JobSatisfaction OverTime StockOptionLevel TrainingTimesLastYear 
          Age_segment Distance_segment Companies_segment;
model YearsAtCompany*Attrition(0)=BusinessTravel Department JobInvolvement JobLevel JobSatisfaction OverTime StockOptionLevel 
          TrainingTimesLastYear Age_segment Distance_segment Companies_segment /ties=efron;
output out=Outp xbeta=Xb resmart=Mart resdev=Dev;
run;
proc sgplot data=Outp;
 yaxis grid;
 refline 0 / axis=y;
 scatter y=Mart x=Xb;
 run;
proc sgplot data=Outp;
 yaxis grid;
 refline 0 / axis=y;
 scatter y=Dev x=Xb;
 run;
 data Outp;
 set Outp; 
if Mart<-1 then delete;
 if-1.5>Dev or 2 <Dev  then delete;
 run;
proc phreg data=work.Outp;
class  BusinessTravel Department JobInvolvement JobLevel JobSatisfaction OverTime StockOptionLevel TrainingTimesLastYear 
          Age_segment Distance_segment Companies_segment;
model YearsAtCompany*Attrition(0)=BusinessTravel Department JobInvolvement JobLevel JobSatisfaction OverTime StockOptionLevel 
          TrainingTimesLastYear Age_segment Distance_segment Companies_segment /ties=efron;
run;



/*1. Model proporcjonalnych hazardów Coxa
W modelu proporcjonalnych hazardów Coxa pierwszy sk³adnik zale¿y tylko od czasu, ale nie zale¿y od wektora
zmiennych objaœniaj¹cych, natomiast drugi nie zale¿y od czasu, tylko od wektora zmiennych objaœniaj¹cych.*/
/* na podstawie wykresów mo¿na ju¿ stwierdzi¿ ze zadna ze zmiennych nie spe³nia  za³o¿enia proporcjonalnych hazardów, 
z kolei ich interakcja z czasem nie jest istotna w modelu */

ods pdf file="C:\Users\ola\Documents\sgh_master\sem2\analiza trwania czasu\PROJEKT\2.pdf" style=journal;

proc phreg data=work.Outp;
class  BusinessTravel Department JobInvolvement JobLevel JobSatisfaction OverTime StockOptionLevel TrainingTimesLastYear 
          Age_segment Distance_segment Companies_segment;
model YearsAtCompany*Attrition(0)=BusinessTravel Department JobInvolvement JobLevel JobSatisfaction OverTime StockOptionLevel 
          TrainingTimesLastYear Age_segment Distance_segment Companies_segment /ties=efron;
run;

ods pdf close;

/*2. Model nieproporcjonalnych hazardów
 w modelu uwzglêdniane s¹ zmienne zale¿ne od czasu, to nadal rozwa¿any jest model Coxa,
ale w takim przypadku nie jest spe³nione za³o¿enie proporcjonalnych hazardów*/

proc lifetest 
data=work.Outp 
method=lt 
plots=(s,h);
time YearsAtCompany*Attrition(0);
strata Promotion_segment;
run;

proc phreg data=work.Outp;
    class BusinessTravel Department JobInvolvement JobLevel JobSatisfaction OverTime StockOptionLevel TrainingTimesLastYear 
          Age_segment Distance_segment Companies_segment;
    model YearsAtCompany*Attrition(0)=BusinessTravel Department JobInvolvement JobLevel JobSatisfaction OverTime StockOptionLevel 
          TrainingTimesLastYear Age_segment Distance_segment Companies_segment promo11 promo12 promo13 promo14 
		  promo14/ties=efron;

	    if YearsAtCompany > 25 then do;
	    promo12 = (Promotion_segment = 2);
	    promo13 = (Promotion_segment = 3);
	    promo14 = (Promotion_segment = 4);
	    promo11 = 1; /* referencja - poziom 1 */
	end;

	if YearsAtCompany <= 25 then do;
	    promo11 = (Promotion_segment = 1);
	    promo12 = 1;
	    promo13 = 1;
	    promo14 = 1;
	end;
run;



 /*Predykcja z wykorzystaniem modelu semiparametrycznego*/
proc phreg data=work.Outp plots=survival;
class  BusinessTravel Department JobInvolvement JobLevel JobSatisfaction OverTime StockOptionLevel TrainingTimesLastYear 
          Age_segment Distance_segment Companies_segment;
model YearsAtCompany*Attrition(0)=BusinessTravel Department JobInvolvement JobLevel JobSatisfaction OverTime StockOptionLevel 
          TrainingTimesLastYear Age_segment Distance_segment Companies_segment /ties=efron;
baseline covariates=work.Projekt_full_clean out=work.Pred_sur_semi survival=_all_ / diradj;
run;

 /*Krzywe ROC zale¿na od czasu*/
proc phreg data=work.Outp plots(overlay=individual)=roc rocoptions(at= 10 20 30 40);
class  BusinessTravel Department JobInvolvement JobLevel JobSatisfaction OverTime StockOptionLevel TrainingTimesLastYear 
          Age_segment Distance_segment Companies_segment;
model YearsAtCompany*Attrition(0)=BusinessTravel Department JobInvolvement JobLevel JobSatisfaction OverTime StockOptionLevel 
          TrainingTimesLastYear Age_segment Distance_segment Companies_segment /ties=efron;
run;

/*Krzywa ROC zale¿na od czasu*/
proc phreg data=work.Outp plots=auc rocoptions(method=ipcw(cl seed=1234) iauc);
class  BusinessTravel Department JobInvolvement JobLevel JobSatisfaction OverTime StockOptionLevel TrainingTimesLastYear 
          Age_segment Distance_segment Companies_segment;
model YearsAtCompany*Attrition(0)=BusinessTravel Department JobInvolvement JobLevel JobSatisfaction OverTime StockOptionLevel 
          TrainingTimesLastYear Age_segment Distance_segment Companies_segment /ties=efron;
run;

/*podejscie bayesowskie*/
/* Estymacja bayesowska parametrów modelu semiparametrycznego*/
 proc phreg data=work.Outp;
 class BusinessTravel Department JobInvolvement JobLevel JobSatisfaction OverTime StockOptionLevel TrainingTimesLastYear 
          Age_segment Distance_segment Companies_segment;
 model YearsAtCompany*Attrition(0)= BusinessTravel Department JobInvolvement JobLevel JobSatisfaction OverTime StockOptionLevel 
          TrainingTimesLastYear Age_segment Distance_segment Companies_segment/ties=efron;
 bayes seed=123 nbi=1000 nmc=5000 coeffprior=normal diagnostics=all;
 ods output PosteriorSample=PS_Projekt;
 run;
