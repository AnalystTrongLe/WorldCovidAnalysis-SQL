/* Insert query from 'WorldCovidAnalysis_ProcessedQuery' to run the Tableau Query */


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