/* Analysis of Our World In Data's COVID-19 Data 2024-01-10
Creator:	Trong Le (Data Analyst)
Last Modified:	2024-01-14
Github:		https://github.com/AnalystTrongLe
Medium:		https://medium.com/@analyst.trong.le
Inspired by:	https://youtu.be/qfyynHBFOsM?si=8lQj6troWABSpWT5
Data Source:	https://github.com/owid/covid-19-data/tree/master/public/data
*/

/* An Overview of this Project
Objectives:
	* Create visuals to describe how COVID-19 changes over time
	* Explain impacts of COVID-19 on the world
	* Identify correlations using common metrics from epidemiology
	* Describe the World's response to COVID-19
Results:
	* Data Preparation: Studied the provided dataset and identified limitations and areas for improvements
	* Data Processing and Wranglings: Isolated, modified, transformed, and filtered data to create a processed dataset
	* Data Analysis: Used the processed dataset, comparative analysis, and statistics to answer the project objectives
	* Data Visualization: Created an exportable dataset for Tableau and queries to highlight certain extremes
*/


--============================================================================


/* Data Preparation
Objectives:
	* Discovering the dataset limitations
	* Understanding what each variable represents
	* Selecting appropriate variables to accomplish project objectives
Results:
	* Use Date as the primary key
	* Location contains 'World' data for COVID-19 cases, deaths, and vaccinations.
	* Covid hospitalizations and excess mortality need to be calculated from the countries's reports
	* Determine filters to reduce outliers with hospitalization and excess mortality datasets
*/

--Preview potentially useful variables
SELECT continent, location, date,
	total_cases, new_cases, total_deaths, new_deaths,
	total_vaccinations, new_vaccinations, people_vaccinated, people_fully_vaccinated,
	population, hosp_patients, excess_mortality, excess_mortality_cumulative, excess_mortality_cumulative_absolute
FROM owid_covid_data_20240110
WHERE location = 'World'
ORDER BY date;

------------------------------------------------------------------------------

--Reviewing completeness of possibly useful variables
SELECT COUNT(continent) AS continent, COUNT(location) AS location, COUNT(date) AS date, 
	COUNT(total_cases) AS totCases, COUNT(new_cases) AS newCases, COUNT(total_deaths) AS totDeaths, COUNT(new_deaths) AS newDeaths,
	COUNT(total_vaccinations) AS totVac, COUNT(new_vaccinations) AS newVac, COUNT(people_vaccinated) AS peopVac, COUNT(people_fully_vaccinated) AS peopFulVac,
	COUNT(population) AS pop, COUNT(hosp_patients) AS hospPatients, COUNT(excess_mortality) AS excMortality, COUNT(excess_mortality_cumulative) excMorCumulative, COUNT(excess_mortality_cumulative_absolute) AS excDeaths
FROM owid_covid_data_20240110;
/*NOTE:
1) Location, Date, and Population are the most reliable variables based on completeness.
2) Continent data is not complete. [Requires Investigation]
3) There are more new cases and new deaths than total cases and total deaths. [Requires Investigation]
4) Total Vaccination does NOT equal New Vaccinations count. [Requires Investigation]
5) Hospitalized Patients are not well reported. [Requires Investigation]
6) All three Excess Mortality variables have equal counts but are underreported compared to other variables. [Requires Investigation]
*/

------------------------------------------------------------------------------

--Investigation Continents
SELECT DISTINCT continent, location
FROM owid_covid_data_20240110
ORDER BY 1;
--Result: Continent is NULL when Location contains continent values.

------------------------------------------------------------------------------

--Investigation 'World' under Locations
SELECT continent, location, date,
	total_cases, new_cases, total_deaths, new_deaths,
	total_vaccinations, new_vaccinations, people_vaccinated, people_fully_vaccinated,
	population, hosp_patients, excess_mortality, excess_mortality_cumulative, excess_mortality_cumulative_absolute
FROM owid_covid_data_20240110
WHERE location = 'World';
--Result: Location 'World' only contains COVID-19 cases, deaths, and vaccinations. Patients hospitalized and all three excess mortality rates are null.
--NOTE: The dataset with Location of 'World' is cumulated by Our World in Data from countries' reportings.

------------------------------------------------------------------------------

--Investigation World's COVID-19 cases and deaths
SELECT SUM(new_cases) sumNewCases, MAX(CAST(total_cases AS float)) maxTotCases, SUM(new_deaths) sumNewDeaths, MAX(CAST(total_deaths AS float)) maxTotDeaths
FROM owid_covid_data_20240110
WHERE location = 'World';
--Result: The total for new cases and new deaths are slightly off from the max of Total Cases and Total deaths but within acceptable margin of error.

------------------------------------------------------------------------------

--Investigation World's Vaccinations
SELECT SUM(CAST(new_vaccinations AS float)) sumNewVac, MAX(CAST(total_vaccinations AS float)) maxTotVac, MAX(CAST(people_vaccinated AS float)) pepVac, MAX(CAST(people_fully_vaccinated AS float)) pepFulVac
FROM owid_covid_data_20240110
WHERE location = 'World';
--Result: The total for new vaccinations is slightly less than the max of Total Vaccination but within acceptable margin of error.

------------------------------------------------------------------------------

--Investigation reported Hospitalized Patients
SELECT APPROX_COUNT_DISTINCT(location) uniqueCountries
FROM owid_covid_data_20240110
WHERE hosp_patients IS NOT NULL;

SELECT date, COUNT(hosp_patients) numReports
FROM owid_covid_data_20240110
GROUP BY date
HAVING COUNT(hosp_patients) > 0
ORDER BY 2;

WITH filtered_hosp_pat
(date, numReports) AS (
	SELECT date, COUNT(hosp_patients)
	FROM owid_covid_data_20240110
	GROUP BY date
	HAVING COUNT(hosp_patients) > 0)
SELECT AVG(numReports) AS avgReports, STDEVP(numReports) * 2 AS 'within_95%_tile', AVG(numReports) - STDEVP(numReports) * 2 AS lowest_accepted_reportings
FROM filtered_hosp_pat;
--Result: Only 40 unique countries reported hospitalization by COVID-19. A filter of 9 or more reports per date should capture 95% of the data while reducing outliers.
--NOTE: Filter of at least 10 reports per date will removes 66 dates or 4.7%.

------------------------------------------------------------------------------

--Investigation reported Excess Mortality
SELECT APPROX_COUNT_DISTINCT(location) uniqueCountries
FROM owid_covid_data_20240110
WHERE excess_mortality IS NOT NULL;

SELECT date, COUNT(excess_mortality) numReports
FROM owid_covid_data_20240110
GROUP BY date
HAVING COUNT(excess_mortality) > 0
ORDER BY 2;

WITH filtered_exc_mort
(date, numReports) AS (
	SELECT date, COUNT(excess_mortality)
	FROM owid_covid_data_20240110
	GROUP BY date
	HAVING COUNT(excess_mortality) > 0)
SELECT AVG(numReports) AS avgReports, STDEVP(numReports) * 2 AS 'within_95%_tile', AVG(numReports) - STDEVP(numReports) * 2 AS suggestedFilter
FROM filtered_exc_mort;
--Result: Only 124 unique countries reported excess mortality. A filter of 20 or more reports per date should capture about 95% of the data while reducing outliers.
--NOTE: Filter of at least 20 reports per date will removes 12 dates or 5.1%.


--============================================================================


/*Data Processing and Wrangling
Objectives:
	* Extract and separate quintessential information
	* Reformatting  variables with inaccurate datatype
	* Reduce computation and query length
Results:
	* Created a uniformed, cleaned, processed, and wrangled dataset called '#ProcessedCovidData'
	* Create various temp tables to select variables, change data types, add filters, and other modifiers
		* Used CAST and CONVERT to change datatypes
		* Used WHERE and HAVING for filters to reduce outliers
		* Selected COVID cases, deaths, and vaccinations from Location with 'World'
			* Provided an alternative to construct the data from individual country reports
		* Calculated 'hospitalization patients' by totaling and filtering from individual country reports
		* Calculated 'excess mortality', 'excess cumulative mortality', and 'excess deaths' from individual country reports
			* Calculated population-weighted averages for excess mortality rate and excess cumulative mortality rate
			* Calculated excess deaths by totaling individual country reports
			* All excess mortality had a filter applied to reduce outliers
	* Used UNION and temp table to merge all temp tables
*/

--Reducing outliers and isolating COVID hospitalized from countries' reportings
DROP TABLE IF EXISTS #smoothedHospPatients;
CREATE TABLE #smoothedHospPatients
(date date, hosp_patients float);

INSERT INTO #smoothedHospPatients
SELECT date, SUM(CONVERT(float,hosp_patients))
FROM owid_covid_data_20240110
GROUP BY date
HAVING COUNT(hosp_patients) > 9;

------------------------------------------------------------------------------

--The World dataset on COVID-19 cases, deaths, and vaccination cumulated by Our World in Data and provided by the World Health Organizations
DROP TABLE IF EXISTS #CovidCasesDeathsAndVaccinations;
CREATE TABLE #CovidCasesDeathsAndVaccinations
(date date, population float,
	total_cases float, new_cases float, total_deaths float, new_deaths float,
	total_vaccinations float, new_vaccinations float, people_vaccinated float, people_fully_vaccinated float);

INSERT INTO #CovidCasesDeathsAndVaccinations
SELECT date, CAST(population AS float),
	CAST(total_cases AS float), new_cases, CAST(total_deaths AS float), new_deaths,
	CAST(total_vaccinations AS float), CAST(new_vaccinations AS float),
	CAST(people_vaccinated AS float), CAST(people_fully_vaccinated AS float)
FROM owid_covid_data_20240110
WHERE location = 'World'
ORDER BY 1;
/* Alternatively, you can calculate the total cases and deaths by adding all the cases and deaths reported by each country.
Here's the code:
SELECT DISTINCT date,
	SUM(new_cases) OVER(ORDER BY date) AS total_cases, SUM(new_cases) OVER(PARTITION BY date) AS new_cases,
	SUM(new_deaths) OVER(ORDER BY date) AS total_deaths, SUM(new_deaths) OVER(PARTITION BY date) AS new_deaths,
	SUM(CONVERT(float, new_vaccinations)) OVER(ORDER BY date) AS total_vaccinations, SUM(CONVERT(float, new_vaccinations)) OVER(PARTITION BY date) AS new_vaccinations,
	SUM(CONVERT(float, people_vaccinated)) OVER(PARTITION BY date) AS people_vaccinated, SUM(CONVERT(float, people_fully_vaccinated)) OVER(PARTITION BY date) AS people_fully_vaccinated
FROM owid_covid_data_20240110
WHERE continent IS NOT NULL
ORDER BY 1;

If you want to include population, add 'population OVER(ORDER BY date)' to the previous code, then use an UPDATE-statement to change 'population' to the world population.
Here's the code to find the world's population using each country's reported population:
SELECT SUM(DISTINCT population)
FROM owid_covid_data_20240110
WHERE continent IS NOT NULL;

I do NOT recommend this approach. The calculated values do not match the World Health Organization's values. Our World in Data's dataset for individual countries may not be complete.
*/

------------------------------------------------------------------------------

--Fracturing excess mortality by population to create weighted averages
DROP TABLE IF EXISTS #fracExcMort;
CREATE TABLE #fracExcMort
(date date, fracExcMort float, fracExcMortCumulative float, sumExcDeaths float);

INSERT INTO #fracExcMort
SELECT date,
	CAST(excess_mortality AS float) * population / SUM(population) OVER(PARTITION BY DATE),
	CAST(excess_mortality_cumulative AS float) * population / SUM(population) OVER(PARTITION BY DATE),
	SUM(CAST(excess_mortality_cumulative_absolute AS float)) OVER(PARTITION BY DATE)
FROM owid_covid_data_20240110
WHERE excess_mortality IS NOT NULL

--Combining fractured excess mortality to create population-weighted averages
DROP TABLE IF EXISTS #excMortWeighted;
CREATE TABLE #excMortWeighted
(date date, excMort float, excMortCumulative float, sumExcDeaths float);

INSERT INTO #excMortWeighted
SELECT DISTINCT date, SUM(fracExcMort) OVER(PARTITION BY date), SUM(fracExcMortCumulative) OVER(PARTITION BY date), sumExcDeaths
FROM #fracExcMort
ORDER BY date;

--Creating the filter to reduce outliers, i.e., smoothing excess mortality rate
DROP TABLE IF EXISTS #excMortFilter;
CREATE TABLE #excMortFilter
(date date);

INSERT INTO #excMortFilter
SELECT date
FROM owid_covid_data_20240110
GROUP BY date
HAVING COUNT(excess_mortality) > 20;

--Applying the filter to the excess mortality by population weighted-average
DROP TABLE IF EXISTS #smoothedExcessDeaths;
CREATE TABLE #smoothedExcessDeaths
(date date, excess_mortality float, excess_mortality_cumulative float, excess_mortality_cumulative_absolute float);

INSERT INTO #smoothedExcessDeaths
SELECT a.date, excMort, excMortCumulative, sumExcDeaths
FROM #excMortFilter AS a
JOIN #excMortWeighted AS b
	ON a.date = b.date

------------------------------------------------------------------------------

--Merging all temp tables as one processed dataset
DROP TABLE IF EXISTS #ProcessedCovidData;
CREATE TABLE #ProcessedCovidData
(date date, hosp_patients float,
	population float, total_cases float, new_cases float, total_deaths float, new_deaths float,
	total_vaccinations float, new_vaccinations float, people_vaccinated float, people_fully_vaccinated float,
	excess_mortality float, excess_mortality_cumulative float, excess_mortality_cumulative_absolute float);

INSERT INTO #ProcessedCovidData
SELECT a.date, hosp_patients,
	population, total_cases, new_cases, total_deaths, new_deaths,
	total_vaccinations, new_vaccinations, people_vaccinated, people_fully_vaccinated,
	excess_mortality, excess_mortality_cumulative, excess_mortality_cumulative_absolute
FROM #smoothedHospPatients AS a
LEFT JOIN #CovidCasesDeathsAndVaccinations AS b
	ON a.date = b.date
LEFT JOIN #smoothedExcessDeaths AS c
	ON a.date = c.date

UNION

SELECT b.date, hosp_patients,
	population, total_cases, new_cases, total_deaths, new_deaths,
	total_vaccinations, new_vaccinations, people_vaccinated, people_fully_vaccinated,
	excess_mortality, excess_mortality_cumulative, excess_mortality_cumulative_absolute
FROM #smoothedHospPatients AS a
RIGHT JOIN #CovidCasesDeathsAndVaccinations AS b
	ON a.date = b.date
LEFT JOIN #smoothedExcessDeaths AS c
	ON a.date = c.date

UNION

SELECT c.date, hosp_patients,
	population, total_cases, new_cases, total_deaths, new_deaths,
	total_vaccinations, new_vaccinations, people_vaccinated, people_fully_vaccinated,
	excess_mortality, excess_mortality_cumulative, excess_mortality_cumulative_absolute
FROM #smoothedHospPatients AS a
LEFT JOIN #CovidCasesDeathsAndVaccinations AS b
	ON a.date = b.date
RIGHT JOIN #smoothedExcessDeaths AS c
	ON a.date = c.date;

/* Run this to check the merge accuracy:
SELECT COUNT(date) date, SUM(hosp_patients) hospPatients,
	SUM(population) pop, SUM(total_cases) totCases, SUM(new_cases) newCases, SUM(total_deaths) totDeaths, SUM(new_deaths) newDeaths,
	SUM(total_vaccinations) totVac, SUM(new_vaccinations) newVac, SUM(people_vaccinated) pepVac, SUM(people_fully_vaccinated) pepFulVac,
	SUM(excess_mortality) excMortality, SUM(excess_mortality_cumulative) excMorCumulative, SUM(excess_mortality_cumulative_absolute) excDeaths
FROM #ProcessedCovidData

SELECT COUNT(a.date) date, SUM(hosp_patients) hospPatients,
	SUM(population) pop, SUM(total_cases) totCases, SUM(new_cases) newCases, SUM(total_deaths) totDeaths, SUM(new_deaths) newDeaths,
	SUM(total_vaccinations) totVac, SUM(new_vaccinations) newVac, SUM(people_vaccinated) pepVac, SUM(people_fully_vaccinated) pepFulVac,
	SUM(excess_mortality) excMortality, SUM(excess_mortality_cumulative) excMorCumulative, SUM(excess_mortality_cumulative_absolute) excDeaths
FROM #CovidCasesDeathsAndVaccinations AS a
FULL JOIN #smoothedExcessDeaths AS b
	ON a.date = b.date
FULL JOIN #smoothedHospPatients AS c
	ON a.date = c.date
*/


--============================================================================


/* Data Analysis
Objectives:
	* Evaluate the characteristic of COVID-19 and how it changes over time
	* Determine the impact of COVID-19
	* Evaluate COVID-19 effect on the healthcare system
	* Analyze the effect of vaccinations
Results:
	* Review COVID-19 in a story structured from statistics to impacts to causes to cure
	* Use common epidemiology metrics to characterize COVID-19
	* Calculated epidemiology metrics to create various comparative analyses
	* Included queries to identify maximums and minimums that may be hard to notice from visuals
*/

/* Cumulative Cases and Deaths */
--Comparing Total Cases with Total Deaths
SELECT date, total_cases, total_deaths
FROM #ProcessedCovidData
WHERE total_cases IS NOT NULL OR total_deaths IS NOT NULL
ORDER BY 1;

--Calculating prevalence rate and fatality rate as percentages
SELECT date,
	total_cases/population * 100 AS prevalence_rate,
	total_deaths/population * 100 AS fatality_rate
FROM #ProcessedCovidData
WHERE total_cases IS NOT NULL OR total_deaths IS NOT NULL
ORDER BY 1;

------------------------------------------------------------------------------

/* New Cases and New Deaths */
--Comparing New Cases with New Deaths
SELECT date, new_cases, new_deaths
FROM #ProcessedCovidData
WHERE new_cases IS NOT NULL OR new_deaths IS NOT NULL
ORDER BY 1;

--Determining the highest new cases and highest new deaths reported
SELECT MAX(new_cases) AS highest_new_cases_reported,
	MAX(new_deaths) AS highest_new_deaths_reported
FROM #ProcessedCovidData
WHERE new_cases IS NOT NULL OR new_deaths IS NOT NULL

--Determining the top 5 reports with the highest new cases and new deaths combined reported
SELECT TOP 5
	date, new_cases, new_deaths, new_cases + new_deaths AS highest_total_reported
FROM #ProcessedCovidData
ORDER BY 4 DESC;

--Calculating incidence rate and mortality rate as units per 1,000,000
SELECT date,
	new_cases/population * 1000000 AS incidence_rate,
	new_deaths/population * 1000000 AS mortality_rate
FROM #ProcessedCovidData
WHERE new_cases IS NOT NULL OR new_deaths IS NOT NULL
ORDER BY 1;

--Determining the highest incidence rate and highest mortality as units per 1,000,000
SELECT MAX(new_cases)/MAX(population) * 1000000 AS highest_incidence_rate,
	MAX(new_deaths)/MAX(population) * 1000000 AS highest_mortality_rate
FROM #ProcessedCovidData
WHERE new_cases IS NOT NULL OR new_deaths IS NOT NULL

------------------------------------------------------------------------------

/* Evaluating the World's Mortality Rate */
--Comparing COVID-19 mortality rate, expected mortality rate, and excess mortality rate by reports
SELECT date,
	new_deaths/population * 100 AS covid_mortality_rate,
	(new_deaths * 100 / population) - excess_mortality AS expected_mortality,
	excess_mortality
FROM #ProcessedCovidData
WHERE new_deaths IS NOT NULL OR excess_mortality IS NOT NULL
ORDER BY 1;

--Determining the top 5 reports with the highest excess mortality rate
SELECT TOP 5
	date, excess_mortality
FROM #ProcessedCovidData
WHERE excess_mortality IS NOT NULL
ORDER BY 2 DESC;

--Determining the top 5 reports with the lowest excess mortality rate
SELECT TOP 5
	date, excess_mortality
FROM #ProcessedCovidData
WHERE excess_mortality IS NOT NULL
ORDER BY 2;

------------------------------------------------------------------------------

/* Evaluating the World's Cumulative Mortality Rate */
--Comparing COVID-19 mortality rate, expected mortality rate, and excess mortality rate by total
SELECT date,
	total_deaths/population * 100 AS covid_cumulative_mortality_rate,
	(total_deaths * 100 / population) - excess_mortality_cumulative AS expected_cumulative_mortality_rate,
	excess_mortality_cumulative AS excess_cumulative_mortality_rate
FROM #ProcessedCovidData
WHERE total_deaths IS NOT NULL OR excess_mortality_cumulative IS NOT NULL
ORDER BY 1;

--Determining the top 5 reports with the highest excess cumulative mortality rate
SELECT TOP 5
	date, excess_mortality_cumulative AS excess_cumulative_mortality
FROM #ProcessedCovidData
WHERE excess_mortality_cumulative IS NOT NULL
ORDER BY 2 DESC;

--Determining when was the lowest excess cumulative mortality rate
SELECT TOP 5
	date, excess_mortality_cumulative AS excess_cumulative_mortality
FROM #ProcessedCovidData
WHERE excess_mortality_cumulative IS NOT NULL
ORDER BY 2;

------------------------------------------------------------------------------

/* Evaluating the World's Absolute-Cumulative Mortality Rate */
--Comparing COVID-19 deaths, expected deaths, and excess deaths
SELECT date, total_deaths AS covid_deaths,
	total_deaths - excess_mortality_cumulative_absolute AS expected_deaths,
	excess_mortality_cumulative_absolute AS excess_deaths
FROM #ProcessedCovidData
WHERE total_deaths IS NOT NULL OR excess_mortality_cumulative_absolute IS NOT NULL
ORDER BY 1;

--Determining the top 5 reports with the highest excess deaths
SELECT TOP 5
	date, total_deaths AS covid_deaths,
	total_deaths - excess_mortality_cumulative_absolute AS expected_deaths,
	excess_mortality_cumulative_absolute AS excess_deaths
FROM #ProcessedCovidData
WHERE total_deaths IS NOT NULL OR excess_mortality_cumulative_absolute IS NOT NULL
ORDER BY 4 DESC;

--Determining when was the lowest excess deaths
SELECT TOP 5
	date, total_deaths AS covid_deaths,
	total_deaths - excess_mortality_cumulative_absolute AS expected_deaths,
	excess_mortality_cumulative_absolute AS excess_deaths
FROM #ProcessedCovidData
WHERE total_deaths IS NOT NULL AND excess_mortality_cumulative_absolute IS NOT NULL
ORDER BY 4;

------------------------------------------------------------------------------

/* Evaluating COVID-19's impact on the healthcare system */
SELECT date, new_cases, new_deaths, hosp_patients
FROM #ProcessedCovidData
WHERE new_cases IS NOT NULL OR new_deaths IS NOT NULL OR hosp_patients IS NOT NULL
ORDER BY 1;

------------------------------------------------------------------------------

/* Determining the effect of vaccination */
--Comparing new cases, new deaths, and new vaccinations
SELECT date, new_cases, new_deaths, new_vaccinations
FROM #ProcessedCovidData
WHERE new_cases IS NOT NULL OR new_deaths IS NOT NULL OR new_vaccinations IS NOT NULL
ORDER BY 1;

--Determining the top 5 reports with the highest new vaccinations
SELECT TOP 5
	date, new_vaccinations AS highest_new_vaccinations
FROM #ProcessedCovidData
ORDER BY 2 DESC;

--Comparing total cases, total deaths, and total vaccinations
SELECT date, total_cases, total_deaths, total_vaccinations
FROM #ProcessedCovidData
WHERE total_cases IS NOT NULL OR total_deaths IS NOT NULL OR total_vaccinations IS NOT NULL
ORDER BY 1;

--Comparing excess deaths with people fully vaccinated
SELECT date, excess_mortality_cumulative_absolute AS excess_deaths, people_fully_vaccinated
FROM #ProcessedCovidData
WHERE excess_mortality_cumulative_absolute IS NOT NULL OR people_fully_vaccinated IS NOT NULL
ORDER BY 1;


--============================================================================


/* Data Visualizations
Objectives:
	* Create an exportable dataset compatible with Tableau
	* Identify data points that may be difficult to determine through visuals
Results:
	* Used CREATE VIEW to create an exportable dataset for Tableau
	* Wrote queries to highlight extremes that may be difficult to notice on visuals
*/
--Creating a permanent table because CREATE VIEW does not work with temp tables
DROP TABLE IF EXISTS tableauWorldCovidData;
CREATE TABLE tableauWorldCovidData
(date date, hosp_patients float,
	population float, total_cases float, new_cases float, total_covid_deaths float, new_covid_deaths float,
	total_vaccinations float, new_vaccinations float, people_vaccinated float, people_fully_vaccinated float,
	excess_mortality float, excess_cumulative_mortality float, excess_deaths float,
	prevalence_rate float, fatality_rate float, incidence_rate_per_1mil float, mortality_rate_per_1mil float,
	covid_mortality_rate float, expected_mortality float, covid_cumulative_mortality_rate float,
	expected_cumulative_mortality_rate float, expected_deaths float);

INSERT INTO tableauWorldCovidData
SELECT *,
	total_cases/population * 100 AS prevalence_rate,
	total_deaths/population * 100 AS fatality_rate,
	new_cases/population * 1000000 AS incidence_rate_per_1mil,
	new_deaths/population * 1000000 AS mortality_rate_per_1mil,
	new_deaths/population * 100 AS covid_mortality_rate,
	(new_deaths * 100 / population) - excess_mortality AS expected_mortality,
	total_deaths/population * 100 AS covid_cumulative_mortality_rate,
	(total_deaths * 100 / population) - excess_mortality_cumulative AS expected_cumulative_mortality_rate,
	total_deaths - excess_mortality_cumulative_absolute AS expected_deaths
FROM #ProcessedCovidData;

--Creating an exportable dataset for Tableau
DROP VIEW IF EXISTS tableauWorldCovidDataView;
CREATE VIEW tableauWorldCovidDataView AS
SELECT *
FROM tableauWorldCovidData;

--Determining the top 5 reports with the highest new cases and new deaths combined reported
SELECT TOP 5
	date, new_cases, new_deaths, new_cases + new_deaths AS highest_total_reported
FROM #ProcessedCovidData
ORDER BY 4 DESC;

--Determining the top 5 reports with the highest excess mortality rate
SELECT TOP 5
	date, excess_mortality
FROM #ProcessedCovidData
WHERE excess_mortality IS NOT NULL
ORDER BY 2 DESC;

--Determining the top 5 reports with the lowest excess mortality rate
SELECT TOP 5
	date, excess_mortality
FROM #ProcessedCovidData
WHERE excess_mortality IS NOT NULL
ORDER BY 2;

--Determining the top 5 reports with the highest excess cumulative mortality rate
SELECT TOP 5
	date, excess_mortality_cumulative AS excess_cumulative_mortality
FROM #ProcessedCovidData
WHERE excess_mortality_cumulative IS NOT NULL
ORDER BY 2 DESC;

--Determining when was the lowest excess cumulative mortality rate
SELECT TOP 5
	date, excess_mortality_cumulative AS excess_cumulative_mortality
FROM #ProcessedCovidData
WHERE excess_mortality_cumulative IS NOT NULL
ORDER BY 2;

--Determining the top 5 reports with the highest excess deaths
SELECT TOP 5
	date, total_deaths AS covid_deaths,
	total_deaths - excess_mortality_cumulative_absolute AS expected_deaths,
	excess_mortality_cumulative_absolute AS excess_deaths
FROM #ProcessedCovidData
WHERE total_deaths IS NOT NULL OR excess_mortality_cumulative_absolute IS NOT NULL
ORDER BY 4 DESC;

--Determining when was the lowest excess deaths
SELECT TOP 5
	date, total_deaths AS covid_deaths,
	total_deaths - excess_mortality_cumulative_absolute AS expected_deaths,
	excess_mortality_cumulative_absolute AS excess_deaths
FROM #ProcessedCovidData
WHERE total_deaths IS NOT NULL AND excess_mortality_cumulative_absolute IS NOT NULL
ORDER BY 4;

--Determining the top 5 reports with the highest new vaccinations
SELECT TOP 5
	date, new_vaccinations AS highest_new_vaccinations
FROM #ProcessedCovidData
ORDER BY 2 DESC;
