/* Remember to download and import the owid_covid_data_20240110.xlsx file before running this query */


--============================================================================


/*Data Processing and Wrangling
Objectives:
	* Extract and separate quintessential information
	* Reformatting variables with inaccurate datatype
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
FROM PortfolioProjects..owid_covid_data_20240110
GROUP BY date
HAVING COUNT(hosp_patients) > 14 AND COUNT(hosp_patients) < 39;

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
FROM PortfolioProjects..owid_covid_data_20240110
WHERE location = 'World'
ORDER BY 1;
/* Alternatively, you can calculate the total cases and deaths by adding all the cases and deaths reported by each country.
Here's the code:
SELECT DISTINCT date,
	SUM(new_cases) OVER(ORDER BY date) AS total_cases, SUM(new_cases) OVER(PARTITION BY date) AS new_cases,
	SUM(new_deaths) OVER(ORDER BY date) AS total_deaths, SUM(new_deaths) OVER(PARTITION BY date) AS new_deaths,
	SUM(CONVERT(float, new_vaccinations)) OVER(ORDER BY date) AS total_vaccinations, SUM(CONVERT(float, new_vaccinations)) OVER(PARTITION BY date) AS new_vaccinations,
	SUM(CONVERT(float, people_vaccinated)) OVER(PARTITION BY date) AS people_vaccinated, SUM(CONVERT(float, people_fully_vaccinated)) OVER(PARTITION BY date) AS people_fully_vaccinated
FROM PortfolioProjects..owid_covid_data_20240110
WHERE continent IS NOT NULL
ORDER BY 1;

If you want to include population, add 'population OVER(ORDER BY date)' to the previous code, then use an UPDATE-statement to change 'population' to the world population.
Here's the code to find the world's population using each country's reported population:
SELECT SUM(DISTINCT population)
FROM PortfolioProjects..owid_covid_data_20240110
WHERE continent IS NOT NULL;

I do NOT recommend this approach. The calculated values do not match the World Health Organization's values. Our World in Data's dataset for individual countries may not be complete.
*/

------------------------------------------------------------------------------

--Fracturing excess mortality by population to create weighted averages
DROP TABLE IF EXISTS #fracExcMort;
CREATE TABLE #fracExcMort
(date date, fracExcMort float, fracExcMortCumulative float, sumExcDeaths float,
	sumTotCovidDeathsByExcDeaths float,sumNewCovidDeathsByExcDeaths float, sumPopulationByExcDeaths float);

INSERT INTO #fracExcMort
SELECT date,
	CAST(excess_mortality AS float) * population / SUM(population) OVER(PARTITION BY DATE),
	CAST(excess_mortality_cumulative AS float) * population / SUM(population) OVER(PARTITION BY DATE),
	SUM(CAST(excess_mortality_cumulative_absolute AS float)) OVER(PARTITION BY DATE),
	SUM(CAST(total_deaths AS float)) OVER(PARTITION BY DATE),
	SUM(CAST(new_deaths AS float)) OVER(PARTITION BY DATE),
	SUM(CAST(population AS float)) OVER(PARTITION BY DATE)
FROM PortfolioProjects..owid_covid_data_20240110
WHERE excess_mortality IS NOT NULL;

--Combining fractured excess mortality to create population-weighted averages
DROP TABLE IF EXISTS #excMortWeighted;
CREATE TABLE #excMortWeighted
(date date, excMort float, excMortCumulative float, sumExcDeaths float,
		sumTotCovidDeathsByExcDeaths float,sumNewCovidDeathsByExcDeaths float, sumPopulationByExcDeaths float);

INSERT INTO #excMortWeighted
SELECT DISTINCT date,
	SUM(fracExcMort) OVER(PARTITION BY date),
	SUM(fracExcMortCumulative) OVER(PARTITION BY date),
	sumExcDeaths, sumTotCovidDeathsByExcDeaths, sumNewCovidDeathsByExcDeaths, sumPopulationByExcDeaths
FROM #fracExcMort
ORDER BY date;

--Creating the filter to reduce outliers, i.e., smoothing excess mortality rate
DROP TABLE IF EXISTS #excMortFilter;
CREATE TABLE #excMortFilter
(date date);

INSERT INTO #excMortFilter
SELECT date
FROM PortfolioProjects..owid_covid_data_20240110
GROUP BY date
HAVING COUNT(excess_mortality) > 30 AND COUNT(excess_mortality) < 70;

--Applying the filter to the excess mortality by population weighted-average
DROP TABLE IF EXISTS #smoothedExcessDeaths;
CREATE TABLE #smoothedExcessDeaths
(date date, excess_mortality float, excess_mortality_cumulative float, excess_mortality_cumulative_absolute float,
	total_deaths_by_excess_mortality float, new_deaths_by_excess_mortality float, population_by_excess_mortality float);

INSERT INTO #smoothedExcessDeaths
SELECT a.date, excMort, excMortCumulative, sumExcDeaths,
	sumTotCovidDeathsByExcDeaths, sumNewCovidDeathsByExcDeaths, sumPopulationByExcDeaths
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
	excess_mortality float, excess_mortality_cumulative float, excess_mortality_cumulative_absolute float,
	total_deaths_by_excess_mortality float, new_deaths_by_excess_mortality float, population_by_excess_mortality float);

INSERT INTO #ProcessedCovidData
SELECT a.date, hosp_patients,
	population, total_cases, new_cases, total_deaths, new_deaths,
	total_vaccinations, new_vaccinations, people_vaccinated, people_fully_vaccinated,
	excess_mortality, excess_mortality_cumulative, excess_mortality_cumulative_absolute,
	total_deaths_by_excess_mortality, new_deaths_by_excess_mortality, population_by_excess_mortality
FROM #smoothedHospPatients AS a
LEFT JOIN #CovidCasesDeathsAndVaccinations AS b
	ON a.date = b.date
LEFT JOIN #smoothedExcessDeaths AS c
	ON a.date = c.date

UNION

SELECT b.date, hosp_patients,
	population, total_cases, new_cases, total_deaths, new_deaths,
	total_vaccinations, new_vaccinations, people_vaccinated, people_fully_vaccinated,
	excess_mortality, excess_mortality_cumulative, excess_mortality_cumulative_absolute,
	total_deaths_by_excess_mortality, new_deaths_by_excess_mortality, population_by_excess_mortality
FROM #smoothedHospPatients AS a
RIGHT JOIN #CovidCasesDeathsAndVaccinations AS b
	ON a.date = b.date
LEFT JOIN #smoothedExcessDeaths AS c
	ON a.date = c.date

UNION

SELECT c.date, hosp_patients,
	population, total_cases, new_cases, total_deaths, new_deaths,
	total_vaccinations, new_vaccinations, people_vaccinated, people_fully_vaccinated,
	excess_mortality, excess_mortality_cumulative, excess_mortality_cumulative_absolute,
	total_deaths_by_excess_mortality, new_deaths_by_excess_mortality, population_by_excess_mortality
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
