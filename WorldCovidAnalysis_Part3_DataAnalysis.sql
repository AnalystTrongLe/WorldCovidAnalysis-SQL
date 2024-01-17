/* Insert query from 'WorldCovidAnalysis_ProcessedQuery' to run the Analysis Query */


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

--Calculating incidence rate and mortality rate
SELECT date,
	new_cases/population * 100 AS incidence_rate,
	new_deaths/population * 100 AS mortality_rate
FROM #ProcessedCovidData
WHERE new_cases IS NOT NULL OR new_deaths IS NOT NULL
ORDER BY 1;

--Determining the highest incidence rate and highest mortality
SELECT MAX(new_cases)/MAX(population) * 100 AS highest_incidence_rate,
	MAX(new_deaths)/MAX(population) * 100 AS highest_mortality_rate
FROM #ProcessedCovidData
WHERE new_cases IS NOT NULL OR new_deaths IS NOT NULL

------------------------------------------------------------------------------

--NOTE: Any variable ending with "by_excess_mortality" was filtered to use only countries who reported excess deaths.

/* Evaluating the World's Mortality Rate */
--Comparing COVID-19 mortality rate and excess mortality rate by reported
SELECT date,
	new_deaths_by_excess_mortality/population_by_excess_mortality * 100 AS covid_mortality_rate,
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
--Comparing COVID-19 cumulative mortality rate and excess cumulative mortality rate by reported
SELECT date,
	total_deaths_by_excess_mortality/population_by_excess_mortality * 100 AS covid_cumulative_mortality,
	excess_mortality_cumulative AS excess_cumulative_mortality
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
--Comparing total COVID-19 deaths and total excess deaths
SELECT date, total_deaths_by_excess_mortality AS total_covid_deaths,
	excess_mortality_cumulative_absolute AS total_excess_deaths
FROM #ProcessedCovidData
WHERE total_deaths IS NOT NULL OR excess_mortality_cumulative_absolute IS NOT NULL
ORDER BY 1;

--Determining the top 5 reports with the highest excess deaths
SELECT TOP 5
	date, total_deaths_by_excess_mortality AS total_covid_deaths,
	excess_mortality_cumulative_absolute AS total_excess_deaths
FROM #ProcessedCovidData
WHERE total_deaths IS NOT NULL OR excess_mortality_cumulative_absolute IS NOT NULL
ORDER BY 3 DESC;

--Determining when was the lowest excess deaths
SELECT TOP 5
	date, total_deaths_by_excess_mortality AS total_covid_deaths,
	excess_mortality_cumulative_absolute AS total_excess_deaths
FROM #ProcessedCovidData
WHERE total_deaths IS NOT NULL AND excess_mortality_cumulative_absolute IS NOT NULL
ORDER BY 3;

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
SELECT date, excess_mortality_cumulative_absolute AS total_excess_deaths, people_fully_vaccinated
FROM #ProcessedCovidData
WHERE excess_mortality_cumulative_absolute IS NOT NULL OR people_fully_vaccinated IS NOT NULL
ORDER BY 1;
