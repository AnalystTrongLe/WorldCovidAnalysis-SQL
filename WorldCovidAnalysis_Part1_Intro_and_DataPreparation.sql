/* Analysis of Our World In Data's COVID-19 Data 2024-01-10
Creator:		Trong Le (Data Analyst)
Last Modified:	2024-01-14
Github:			https://github.com/AnalystTrongLe
Medium:			https://medium.com/@analyst.trong.le
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