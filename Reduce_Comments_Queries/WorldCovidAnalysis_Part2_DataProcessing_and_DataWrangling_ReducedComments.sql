/* Remember to download and import the owid_covid_data_20240110.xlsx file before running this query */

--============================================================================

/* Data Processing and Wrangling */
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
