SELECT * FROM Raw_Survey_Data LIMIT 50;

-- Create Country Details table.  Use row_number with group by to create primary key
-- country_id for each unique combination of state, city and zip code.  
CREATE TABLE Dim_Country_Details AS
SELECT
    ROW_NUMBER() OVER () AS Country_Id,          -- unique ID
    'USA' AS Country_Name,                       -- default country
    "State",
    "City",
    "ZIP Code" AS ZipCode
FROM Raw_Survey_Data
GROUP BY "State", "City", "ZIP Code";

-- Check resulting table
-- SELECT * FROM Dim_Country_Details LIMIT 10;

-- Create hospital details table.  Create PK hospital_id using primary key autoincrement to ensure 
-- uniqueness, flexibility, predictability and consistency.  Use FK to link table to country details table.

CREATE TABLE Dim_Hospital_Details (
    hospital_id INTEGER PRIMARY KEY AUTOINCREMENT,  -- surrogate/primary key
    country_id INTEGER,                             -- FK to Dim_Country_Details
    hospital_name TEXT,
    city TEXT,
    location TEXT,
    FOREIGN KEY (country_id) REFERENCES Dim_Country_Details(country_id)
);

INSERT INTO Dim_Hospital_Details  (country_id, hospital_name, city, location)
SELECT DISTINCT
    c.country_id,
    s."Hospital Name",
    s.City,
    s.Location
FROM Raw_Survey_Data s
JOIN Dim_Country_Details c
    ON s.City = c.City AND s."ZIP Code" = c.ZipCode;

-- Create measure deatils table with unique numberical measure id while keeping original source measure_ID.  
CREATE TABLE Dim_Measure_Details (
    measure_id INTEGER PRIMARY KEY AUTOINCREMENT,  -- surrogate/primary key
    source_measure_id  INTEGER,                   
    measure_start_date DATE,
    measure_end_date DATE
);

INSERT INTO Dim_Measure_Details (source_measure_id, measure_start_date, measure_end_date)
SELECT DISTINCT
  "Measure id",
  "Measure Start Date",
  "Measure End Date"
FROM Raw_Survey_Data r;

-- Check progress
-- select * from Dim_Measure_Details group by measure_id;


CREATE TABLE IF NOT EXISTS Dim_Survey_Details (
    Survey_id INTEGER PRIMARY KEY AUTOINCREMENT,  -- surrogate/primary key
    Survey_Question TEXT,
    Answer_Description TEXT,
    Patient_Survey_Star_Rating_Footnote TEXT
);

select * from Dim_Survey_Details;

INSERT INTO Dim_Survey_Details (Survey_Question, Answer_Description, Patient_Survey_Star_Rating_Footnote)
SELECT DISTINCT
    Question,
    "Answer Description",
    "Patient Survey Star Rating Footnote"
FROM Raw_Survey_Data;

PRAGMA table_info(Raw_Survey_Data);

CREATE TABLE IF NOT EXISTS Fact_Patient_Survey (
country_id INTEGER,
hospital_id INTEGER,
measure_id INTEGER,
survey_id INTEGER,
number_of_completed_surveys INTEGER,
number_of_completed_surveys_footnote TEXT,
survey_response_rate_percent FLOAT,
survey_response_rate_percent_footnote TEXT,
linear_mean_value TEXT,
answer_percent FLOAT,
patient_survey_star_rating TEXT,
FOREIGN KEY (country_id) REFERENCES Dim_Country_Details(country_id),
FOREIGN KEY (hospital_id) REFERENCES Dim_Hospital_Details(hospital_id),
FOREIGN KEY (measure_id) REFERENCES Dim_Measure_Details(measure_id),
FOREIGN KEY (survey_id) REFERENCES Dim_Survey_Details(survey_id)
);

SELECT name FROM sqlite_master WHERE type='table';

INSERT INTO Fact_Patient_Survey (country_id, hospital_id, measure_id, survey_id,
number_of_completed_surveys, number_of_completed_surveys_footnote, survey_response_rate_percent,
survey_response_rate_percent_footnote, linear_mean_value, answer_percent, 
patient_survey_star_rating)
SELECT
    c.country_id,
    h.hospital_id,
    m.measure_id,
    s.survey_id,
    r."Number of Completed Surveys",
    r."Number of Completed Surveys Footnote",
    r."Survey Response Rate Percent",
    r."Survey Response Rate Percent Footnote",
    r."Linear Mean Value",
    r."Answer Percent",
    r."Patient Survey Star Rating"
FROM    
    Raw_Survey_Data r
JOIN  
    Dim_Country_Details c
ON c.ZipCode = r."ZIP Code" AND c.city = r.City
JOIN
    Dim_Hospital_Details h
ON h.hospital_name = r."Hospital Name" AND h.city = r."City"
JOIN   
    Dim_Measure_Details m
ON m.source_measure_id = r."Measure ID" AND m.measure_start_date = r."Measure Start Date"
AND m.measure_end_date = r."Measure End Date"
JOIN
    Dim_Survey_Details s
ON s.Survey_Question = r.Question AND s.Answer_Description = r."Answer Description"
AND s.Patient_Survey_Star_Rating_Footnote = r."Patient Survey Star Rating Footnote";

SELECT * FROM Fact_Patient_Survey LIMIT 10;

SELECT * FROM Fact_Patient_Survey;

SELECT * FROM Dim_Survey_Details;

SELECT "Number of Completed Surveys", COUNT(*) AS count
FROM Raw_Survey_Data
GROUP BY "Number of Completed Surveys"
ORDER BY count DESC;

SELECT AVG(Survey Response Rate Percent) from Raw_Survey_Data;

SELECT 
  *,
  CASE 
    WHEN "Survey Response Rate Percent" != 'Not Available'
    THEN CAST("Survey Response Rate Percent" AS FLOAT)
    ELSE NULL
  END AS survey_response_rate_float
FROM Raw_Survey_Data;

ALTER TABLE Fact_Patient_Survey
ADD COLUMN survey_response_rate_float REAL;

UPDATE Fact_Patient_Survey
SET survey_response_rate_float = (
    SELECT 
        CAST(r."Survey Response Rate Percent" AS REAL)
    FROM Raw_Survey_Data r
    WHERE 
        r."ZIP Code" = (
            SELECT ZipCode FROM Dim_Country_Details c
            WHERE c.country_id = Fact_Patient_Survey.country_id
        )
        AND r."Hospital Name" = (
            SELECT hospital_name FROM Dim_Hospital_Details h
            WHERE h.hospital_id = Fact_Patient_Survey.hospital_id
        )
        AND r."Measure ID" = (
            SELECT source_measure_id FROM Dim_Measure_Details m
            WHERE m.measure_id = Fact_Patient_Survey.measure_id
        )
        AND r."Question" = (
            SELECT Survey_Question FROM Dim_Survey_Details s
            WHERE s.survey_id = Fact_Patient_Survey.survey_id
        )
    LIMIT 1
)
WHERE 
    survey_response_rate_float IS NULL
    AND EXISTS (
        SELECT 1
        FROM Raw_Survey_Data r
        WHERE r."Survey Response Rate Percent" != 'Not Available'
    );

SELECT *
FROM "Health Care_Patient_survey_source"
LIMIT 100;

SELECT measure_id, 
DISTINCT survey_response_rate_float
FROM Fact_Patient_Survey
WHERE measure_id = 55;


-- Step 1: Add the column if it doesn't already exist
ALTER TABLE Dim_Measure_Details
ADD COLUMN survey_response_rate_float REAL;

-- Step 2: Update the column with the average from the fact table
UPDATE Dim_Measure_Details
SET survey_response_rate_float = (
    SELECT f.survey_response_rate_float
    FROM Fact_Patient_Survey f
    WHERE f.measure_id = Dim_Measure_Details.measure_id
      AND f.survey_response_rate_float IS NOT NULL
);

select * from Dim_Measure_Details;

-- Step 1: Aggregate
WITH avg_rates AS (
    SELECT
        measure_id,
        AVG(survey_response_rate_float) AS avg_response_rate
    FROM Fact_Patient_Survey
    WHERE survey_response_rate_float IS NOT NULL
    GROUP BY measure_id
)

-- Step 2: Update dim table
UPDATE Dim_Measure_Details
SET survey_response_rate_float = (
    SELECT avg_response_rate
    FROM avg_rates
    WHERE avg_rates.measure_id = Dim_Measure_Details.measure_id
)
WHERE EXISTS (
    SELECT 1
    FROM avg_rates
    WHERE avg_rates.measure_id = Dim_Measure_Details.measure_id
);

SELECT measure_id, AVG(survey_response_rate_percent) FROM
Fact_Patient_Survey GROUP BY measure_id;

SELECT * FROM Raw_Survey_Data LIMIT 10;

SELECT "Survey Response Rate Percent", COUNT(DISTINCT "Measure ID")
FROM Raw_Survey_Data
GROUP BY "Survey Response Rate Percent"
ORDER BY COUNT(DISTINCT "Measure ID") DESC;

-- Step 1: Remove old float column if it's wrong (optional)
ALTER TABLE Fact_Patient_Survey DROP COLUMN survey_response_rate_float;

-- Step 2: Add it fresh (if not already present)
ALTER TABLE Fact_Patient_Survey
ADD COLUMN survey_response_rate_float REAL;

-- Step 3: Update values from Raw_Survey_Data via hospital ID
UPDATE Fact_Patient_Survey
SET survey_response_rate_float = (
    SELECT CAST(r."Survey Response Rate Percent" AS REAL)
    FROM Raw_Survey_Data r
    WHERE r."Facility ID" = Fact_Patient_Survey.hospital_id
      AND r."Survey Response Rate Percent" IS NOT NULL
      AND r."Survey Response Rate Percent" != 'Not Available'
    LIMIT 1
)
WHERE survey_response_rate_float IS NULL;

UPDATE Fact_Patient_Survey
SET survey_response_rate_float = (
    SELECT CAST(r."Survey Response Rate Percent" AS REAL)
    FROM Raw_Survey_Data r
    WHERE r."Facility ID" = Fact_Patient_Survey.hospital_id
      AND r."Survey Response Rate Percent" IS NOT NULL
      AND r."Survey Response Rate Percent" != 'Not Available'
    LIMIT 1
)
WHERE survey_response_rate_float IS NULL;

-- Step: Update using a JOIN with Raw_Survey_Data
UPDATE Fact_Patient_Survey
SET survey_response_rate_float = (
    SELECT CAST(r."Survey Response Rate Percent" AS REAL)
    FROM Raw_Survey_Data r
    WHERE r."Provider ID" = Fact_Patient_Survey.hospital_id
      AND r."Survey Response Rate Percent" IS NOT NULL
      AND r."Survey Response Rate Percent" != 'Not Available'
    LIMIT 1
)
WHERE EXISTS (
    SELECT 1
    FROM Raw_Survey_Data r
    WHERE r."Provider ID" = Fact_Patient_Survey.hospital_id
      AND r."Survey Response Rate Percent" IS NOT NULL
      AND r."Survey Response Rate Percent" != 'Not Available'
);

PRAGMA table_info(Raw_Survey_Data);
PRAGMA table_info(Fact_Patient_Survey);

SELECT 
    measure_id,
    hospital_id,
    survey_response_rate_float
FROM 
    Fact_Patient_Survey
WHERE 
    survey_response_rate_float IS NOT NULL
LIMIT 20;

PRAGMA table_info(Fact_Patient_Survey);

SELECT 
    COUNT(*) AS total_rows,
    SUM(CASE WHEN survey_response_rate_float IS NOT NULL THEN 1 ELSE 0 END) AS non_null_count
FROM 
    Fact_Patient_Survey;

SELECT "Provider ID", "Survey Response Rate Percent"
FROM Raw_Survey_Data
LIMIT 20;

SELECT DISTINCT "Survey Response Rate Percent"
FROM Raw_Survey_Data
ORDER BY 1;

SELECT DISTINCT r."Provider ID"
FROM Raw_Survey_Data r
LEFT JOIN Fact_Patient_Survey f
  ON r."Provider ID" = f.hospital_id
WHERE f.hospital_id IS NULL;

PRAGMA table_info(Raw_Survey_Data);

PRAGMA table_info(Fact_Patient_Survey);

UPDATE Fact_Patient_Survey
SET survey_response_rate_float = (
    SELECT CAST(r."Survey Response Rate Percent" AS REAL)
    FROM Raw_Survey_Data r
    WHERE CAST(r."Provider ID" AS INTEGER) = Fact_Patient_Survey.hospital_id
      AND r."Survey Response Rate Percent" IS NOT NULL
      AND r."Survey Response Rate Percent" != 'Not Available'
    LIMIT 1
)
WHERE survey_response_rate_float IS NULL;

SELECT
    COUNT(*) AS total_rows,
    SUM(CASE WHEN survey_response_rate_float IS NOT NULL THEN 1 ELSE 0 END) AS non_null_count,
    MIN(survey_response_rate_float) AS min_value,
    MAX(survey_response_rate_float) AS max_value
FROM Fact_Patient_Survey;

PRAGMA table_info(Raw_Survey_Data);
PRAGMA table_info(Fact_Patient_Survey);

SELECT DISTINCT CAST("Provider ID" AS INTEGER) FROM Raw_Survey_Data ORDER BY 1 LIMIT 20;
SELECT DISTINCT hospital_id FROM Fact_Patient_Survey ORDER BY 1 LIMIT 20;

SELECT DISTINCT hospital_id, measure_id, survey_response_rate_float
FROM Fact_Patient_Survey
ORDER BY hospital_id, measure_id;

SELECT DISTINCT "Survey Response Rate Percent"
FROM Raw_Survey_Data
ORDER BY 1;

SELECT DISTINCT CAST("Provider ID" AS INTEGER)
FROM Raw_Survey_Data
ORDER BY 1;

SELECT DISTINCT hospital_id
FROM Fact_Patient_Survey
ORDER BY 1;

SELECT COUNT(*) 
FROM Fact_Patient_Survey f
JOIN (
    SELECT DISTINCT CAST("Provider ID" AS INTEGER) AS provider_id_int
    FROM Raw_Survey_Data
) r
ON f.hospital_id = r.provider_id_int;

SELECT *
FROM dim_hospital_survery
LIMIT 20;
SELECT name FROM sqlite_master WHERE type='table';

SELECT * FROM Dim_Hospital_Details LIMIT 20;

SELECT 
    measure_id, 
    AVG(survey_response_rate_percent) AS avg_response_rate
FROM Fact_Patient_Survey
GROUP BY measure_id;

SELECT DISTINCT survey_response_rate_percent
FROM Fact_Patient_Survey
ORDER BY 1;

SELECT 
    measure_id, 
    AVG(CAST(survey_response_rate_percent AS FLOAT)) AS avg_response_rate
FROM Fact_Patient_Survey
WHERE survey_response_rate_percent != 'Not Available'
GROUP BY measure_id;

-- How many distinct values exist in Fact_Patient_Survey
SELECT COUNT(DISTINCT survey_response_rate_percent) FROM Fact_Patient_Survey;

-- Check if survey_response_rate_percent varies by hospital_id
SELECT hospital_id, COUNT(DISTINCT survey_response_rate_percent)
FROM Fact_Patient_Survey
GROUP BY hospital_id
ORDER BY COUNT(DISTINCT survey_response_rate_percent) DESC;

-- Check if survey_response_rate_percent varies by measure_id
SELECT measure_id, COUNT(DISTINCT survey_response_rate_percent)
FROM Fact_Patient_Survey
GROUP BY measure_id
ORDER BY COUNT(DISTINCT survey_response_rate_percent) DESC;

DROP TABLE IF EXISTS Fact_Patient_Survey;

CREATE TABLE Fact_Patient_Survey AS
SELECT
    c.country_id,
    h.hospital_id,
    m.measure_id,
    s.survey_id,
    CAST(r."Number of Completed Surveys" AS INTEGER) AS number_of_completed_surveys,
    r."Number of Completed Surveys Footnote" AS number_of_completed_surveys_footnote,
    CAST(r."Survey Response Rate Percent" AS FLOAT) AS survey_response_rate_percent,
    r."Survey Response Rate Percent Footnote" AS survey_response_rate_percent_footnote,
    r."Linear Mean Value" AS linear_mean_value,
    CAST(r."Answer Percent" AS FLOAT) AS answer_percent,
    r."Patient Survey Star Rating" AS patient_survey_star_rating
FROM Raw_Survey_Data r
INNER JOIN Dim_Hospital_Details h ON CAST(r."Provider ID" AS INTEGER) = h.hospital_id
INNER JOIN Dim_Country_Details c ON h.country_id = c.country_id
INNER JOIN Dim_Measure_Details m ON r."Measure ID" = m.measure_id
INNER JOIN Dim_Survey_Details s ON r."Survey ID" = s.survey_id
WHERE r."Survey Response Rate Percent" != 'Not Available'
  AND r."Survey Response Rate Percent" IS NOT NULL;

DROP TABLE IF EXISTS Fact_Patient_Survey;

CREATE TABLE Fact_Patient_Survey AS
SELECT
    c.country_id,
    h.hospital_id,
    m.measure_id,
    s.survey_id,
    CAST(r."Number of Completed Surveys" AS INTEGER) AS number_of_completed_surveys,
    r."Number of Completed Surveys Footnote" AS number_of_completed_surveys_footnote,
    CAST(r."Survey Response Rate Percent" AS FLOAT) AS survey_response_rate_percent,
    r."Survey Response Rate Percent Footnote" AS survey_response_rate_percent_footnote,
    r."Linear Mean Value" AS linear_mean_value,
    CAST(r."Answer Percent" AS FLOAT) AS answer_percent,
    r."Patient Survey Star Rating" AS patient_survey_star_rating
FROM    
    Raw_Survey_Data r
INNER JOIN Dim_Country_Details c
    ON c.ZipCode = r."ZIP Code" AND c.city = r.City
INNER JOIN Dim_Hospital_Details h
    ON h.hospital_name = r."Hospital Name" AND h.city = r."City"
INNER JOIN Dim_Measure_Details m
    ON m.source_measure_id = r."Measure ID"
    AND m.measure_start_date = r."Measure Start Date"
    AND m.measure_end_date = r."Measure End Date"
INNER JOIN Dim_Survey_Details s
    ON s.Survey_Question = r.Question
    AND s.Answer_Description = r."Answer Description"
    AND s.Patient_Survey_Star_Rating_Footnote = r."Patient Survey Star Rating Footnote"
WHERE r."Survey Response Rate Percent" != 'Not Available'
  AND r."Survey Response Rate Percent" IS NOT NULL;

SELECT * FROM Fact_Patient_Survey LIMIT 20;

SELECT measure_id, AVG(survey_response_rate_percent) AS avg_response_rate
FROM Fact_Patient_Survey
GROUP BY measure_id;

SELECT "Provider ID", "Measure ID", "Survey Response Rate Percent"
FROM Raw_Survey_Data
WHERE "Survey Response Rate Percent" != 'Not Available'
LIMIT 100;

-- Top 3 states by response rate
SELECT
    c.state,
    ROUND(AVG(f.survey_response_rate_percent), 2) AS avg_survey_response_rate
FROM
    Fact_Patient_Survey f
JOIN
    Dim_Country_Details c ON f.country_id = c.country_id
WHERE
    f.survey_response_rate_percent IS NOT NULL
GROUP BY
    c.state
ORDER BY
    avg_survey_response_rate DESC
LIMIT 3;


-- Top 3 states by response rate with overall average
WITH State_Averages AS (
    SELECT
        c.state,
        ROUND(AVG(f.survey_response_rate_percent), 2) AS avg_survey_response_rate
    FROM
        Fact_Patient_Survey f
    JOIN
        Dim_Country_Details c ON f.country_id = c.country_id
    WHERE
        f.survey_response_rate_percent IS NOT NULL
    GROUP BY
        c.state
),

Top_3_States AS (
    SELECT
        state,
        avg_survey_response_rate
    FROM
        State_Averages
    ORDER BY
        avg_survey_response_rate DESC
    LIMIT 3
),

Overall_Avg AS (
    SELECT
        'All States Average' AS state,
        ROUND(AVG(avg_survey_response_rate), 2) AS avg_survey_response_rate
    FROM
        State_Averages
)

SELECT * FROM Top_3_States
UNION ALL
SELECT * FROM Overall_Avg;


SELECT * FROM Fact_Patient_Survey limit 100;

SELECT DISTINCT "Patient Survey Star Rating"
FROM Raw_Survey_Data
ORDER BY 1;

SELECT DISTINCT patient_survey_star_rating
FROM Fact_Patient_Survey
ORDER BY 1;

SELECT "Patient Survey Star Rating", COUNT(*)
FROM Raw_Survey_Data
GROUP BY 1
ORDER BY 1;

SELECT "Patient Survey Star Rating", "Patient Survey Star Rating Footnote", COUNT(*)
FROM Raw_Survey_Data
GROUP BY 1, 2
ORDER BY 1, 2;

DROP TABLE IF EXISTS Fact_Patient_Survey;

CREATE TABLE IF NOT EXISTS Fact_Patient_Survey (
    country_id INTEGER,
    hospital_id INTEGER,
    measure_id INTEGER,
    survey_id INTEGER,
    number_of_completed_surveys INTEGER,
    number_of_completed_surveys_footnote TEXT,
    survey_response_rate_percent FLOAT,
    survey_response_rate_percent_footnote TEXT,
    linear_mean_value TEXT,
    answer_percent FLOAT,
    patient_survey_star_rating TEXT,
    FOREIGN KEY (country_id) REFERENCES Dim_Country_Details(country_id),
    FOREIGN KEY (hospital_id) REFERENCES Dim_Hospital_Details(hospital_id),
    FOREIGN KEY (measure_id) REFERENCES Dim_Measure_Details(measure_id),
    FOREIGN KEY (survey_id) REFERENCES Dim_Survey_Details(survey_id)
);

-- safe join on Survey Question and Answer Description only, ignoring star rating footnote mismatch
INSERT INTO Fact_Patient_Survey (
    country_id, hospital_id, measure_id, survey_id,
    number_of_completed_surveys, number_of_completed_surveys_footnote,
    survey_response_rate_percent, survey_response_rate_percent_footnote,
    linear_mean_value, answer_percent, patient_survey_star_rating
)
SELECT
    c.country_id,
    h.hospital_id,
    m.measure_id,
    s.survey_id,
    CAST(r."Number of Completed Surveys" AS INTEGER),
    r."Number of Completed Surveys Footnote",
    CAST(r."Survey Response Rate Percent" AS FLOAT),
    r."Survey Response Rate Percent Footnote",
    r."Linear Mean Value",
    CAST(r."Answer Percent" AS FLOAT),
    r."Patient Survey Star Rating"
FROM
    Raw_Survey_Data r
JOIN Dim_Country_Details c
    ON c.ZipCode = r."ZIP Code"
    AND c.city = r.City
JOIN Dim_Hospital_Details h
    ON h.hospital_name = r."Hospital Name"
    AND h.city = r."City"
JOIN Dim_Measure_Details m
    ON m.source_measure_id = r."Measure ID"
    AND m.measure_start_date = r."Measure Start Date"
    AND m.measure_end_date = r."Measure End Date"
JOIN Dim_Survey_Details s
    ON s.Survey_Question = r.Question
    AND s.Answer_Description = r."Answer Description";

select distinct patient_survey_star_rating from Fact_Patient_Survey;

.mode csv
.headers on
.output fact_survey.csv
SELECT * FROM Fact_Patient_Survey;
.output stdout

select survey_response_rate_percent from Fact_Patient_Survey limit 100;

select AVG(number_of_completed_surveys) from Fact_Patient_Survey;

select distinct(linear_mean_value) from Fact_Patient_Survey;

select AVG(patient_survey_star_rating), number_of_completed_surveys FROM Fact_Patient_Survey 
where city = "gardena";

SELECT 
    DISTINCT(Survey_Question)
FROM
    Dim_Survey_Details
WHERE 
    (
        Survey_Question LIKE '%star rating%'
        OR Survey_Question LIKE '%linear mean%'
    );

SELECT
    c.state,
    ROUND(AVG(CASE WHEN s.survey_question LIKE '%Nurse communication - linear mean score%' THEN f.linear_mean_value ELSE NULL END), 2) AS nurse_score,
    ROUND(AVG(CASE WHEN s.survey_question LIKE '%Cleanliness - linear mean score%' THEN f.linear_mean_value ELSE NULL END), 2) AS clean_score,
    ROUND(AVG(CASE WHEN s.survey_question LIKE '%Doctor communication - linear mean score%' THEN f.linear_mean_value ELSE NULL END), 2) AS doctor_score,
    ROUND(AVG(CASE WHEN s.survey_question LIKE '%Staff responsiveness - linear mean score%' THEN f.linear_mean_value ELSE NULL END), 2) AS staff_score,
    ROUND(AVG(CASE WHEN s.survey_question LIKE '%Quietness - linear mean score%' THEN f.linear_mean_value ELSE NULL END), 2) AS quiet_score,
    ROUND(AVG(CASE WHEN s.survey_question LIKE '%Overall hospital rating - linear mean score%' THEN f.linear_mean_value ELSE NULL END), 2) AS overall_score
FROM
    Fact_Patient_Survey f
JOIN
    Dim_Hospital_Details h ON f.hospital_id = h.hospital_id
JOIN
    Dim_Country_Details c ON f.country_id = c.country_id
JOIN
    Dim_Survey_Details s ON f.survey_id = s.survey_id
WHERE
    f.linear_mean_value IS NOT NULL
GROUP BY
    c.state
HAVING
    SUM(f.number_of_completed_surveys) >= 100;

-- SELECT
--     c.state,
--     s.survey_question,
--     f.linear_mean_value,
--     f.number_of_completed_surveys
-- FROM
--     Fact_Patient_Survey f
-- JOIN
--     Dim_Hospital_Details h ON f.hospital_id = h.hospital_id
-- JOIN
--     Dim_Country_Details c ON f.country_id = c.country_id
-- JOIN
--     Dim_Survey_Details s ON f.survey_id = s.survey_id
-- WHERE
--     s.survey_question LIKE '%linear mean score%'
--     AND c.state = 'AK'
-- ORDER BY 
--     f.linear_mean_value
-- LIMIT 100;

SELECT
    c.state,
    ROUND(SUM(CASE WHEN s.survey_question LIKE '%Nurse communication - linear mean score%' THEN f.linear_mean_value * f.number_of_completed_surveys ELSE 0 END)/
          SUM(CASE WHEN s.survey_question LIKE '%Nurse communication - linear mean score%' THEN f.number_of_completed_surveys ELSE 0 END), 2) AS nurse_score,

    ROUND(SUM(CASE WHEN s.survey_question LIKE '%Cleanliness - linear mean score%' THEN f.linear_mean_value * f.number_of_completed_surveys ELSE 0 END)/
          SUM(CASE WHEN s.survey_question LIKE '%Cleanliness - linear mean score%' THEN f.number_of_completed_surveys ELSE 0 END), 2) AS clean_score,

    ROUND(SUM(CASE WHEN s.survey_question LIKE '%Doctor communication - linear mean score%' THEN f.linear_mean_value * f.number_of_completed_surveys ELSE 0 END)/
          SUM(CASE WHEN s.survey_question LIKE '%Doctor communication - linear mean score%' THEN f.number_of_completed_surveys ELSE 0 END), 2) AS doctor_score,

    ROUND(SUM(CASE WHEN s.survey_question LIKE '%Staff responsiveness - linear mean score%' THEN f.linear_mean_value * f.number_of_completed_surveys ELSE 0 END)/
          SUM(CASE WHEN s.survey_question LIKE '%Staff responsiveness - linear mean score%' THEN f.number_of_completed_surveys ELSE 0 END), 2) AS staff_score,

    ROUND(SUM(CASE WHEN s.survey_question LIKE '%Quietness - linear mean score%' THEN f.linear_mean_value * f.number_of_completed_surveys ELSE 0 END)/
          SUM(CASE WHEN s.survey_question LIKE '%Quietness - linear mean score%' THEN f.number_of_completed_surveys ELSE 0 END), 2) AS quiet_score,

    ROUND(SUM(CASE WHEN s.survey_question LIKE '%Overall hospital rating - linear mean score%' THEN f.linear_mean_value * f.number_of_completed_surveys ELSE 0 END)/
          SUM(CASE WHEN s.survey_question LIKE '%Overall hospital rating - linear mean score%' THEN f.number_of_completed_surveys ELSE 0 END), 2) AS overall_score

FROM
    Fact_Patient_Survey f
INNER JOIN
    Dim_Hospital_Details h ON f.hospital_id = h.hospital_id
INNER JOIN
    Dim_Country_Details c ON f.country_id = c.country_id
INNER JOIN
    Dim_Survey_Details s ON f.survey_id = s.survey_id
WHERE
    f.linear_mean_value IS NOT NULL
GROUP BY
    c.state
HAVING
    SUM(f.number_of_completed_surveys) >= 100;

-- Top 3 states and overall average 
WITH State_Averages AS (
    SELECT
        c.state,
        ROUND(
            SUM(f.survey_response_rate_percent * f.number_of_completed_surveys) * 1.0 /
            SUM(f.number_of_completed_surveys),
            2
        ) AS avg_survey_response_rate
    FROM
        Fact_Patient_Survey f
    INNER JOIN
        Dim_Country_Details c ON f.country_id = c.country_id
    WHERE
        f.survey_response_rate_percent IS NOT NULL
        AND f.number_of_completed_surveys IS NOT NULL
    GROUP BY
        c.state
),

Top_3_States AS (
    SELECT
        state,
        avg_survey_response_rate
    FROM
        State_Averages
    ORDER BY
        avg_survey_response_rate DESC
    LIMIT 3
),

Overall_Avg AS (
    SELECT
        'All States Average' AS state,
        ROUND(AVG(avg_survey_response_rate), 2) AS avg_survey_response_rate
    FROM
        State_Averages
)

SELECT * FROM Top_3_States
UNION ALL
SELECT * FROM Overall_Avg;

select location from Raw_Survey_Data limit 1;

.mode csv
.headers on
.output hospital_linear_scores_v5.csv

SELECT
    f.hospital_id,
    hd.hospital_name,
    cd.ZipCode,
    ROUND(AVG(CASE WHEN s.survey_question LIKE '%Nurse communication - linear mean score%' THEN f.linear_mean_value ELSE NULL END), 2) AS nurse_score,
    ROUND(AVG(CASE WHEN s.survey_question LIKE '%Cleanliness - linear mean score%' THEN f.linear_mean_value ELSE NULL END), 2) AS clean_score,
    ROUND(AVG(CASE WHEN s.survey_question LIKE '%Doctor communication - linear mean score%' THEN f.linear_mean_value ELSE NULL END), 2) AS doctor_score,
    ROUND(AVG(CASE WHEN s.survey_question LIKE '%Staff responsiveness - linear mean score%' THEN f.linear_mean_value ELSE NULL END), 2) AS staff_score,
    ROUND(AVG(CASE WHEN s.survey_question LIKE '%Quietness - linear mean score%' THEN f.linear_mean_value ELSE NULL END), 2) AS quiet_score,
    ROUND(AVG(CASE WHEN s.survey_question LIKE '%Communication about medicines - linear mean score%' THEN f.linear_mean_value ELSE NULL END), 2) AS med_communication_score,
    ROUND(AVG(CASE WHEN s.survey_question LIKE '%Discharge information - linear mean score%' THEN f.linear_mean_value ELSE NULL END), 2) AS discharge_score,
    ROUND(AVG(CASE WHEN s.survey_question LIKE '%Care transition - linear mean score%' THEN f.linear_mean_value ELSE NULL END), 2) AS care_transition_score,
    ROUND(AVG(CASE WHEN s.survey_question LIKE '%Overall hospital rating - linear mean score%' THEN f.linear_mean_value ELSE NULL END), 2) AS overall_score,
    ROUND(AVG(CASE WHEN s.survey_question LIKE '%Recommend hospital - linear mean score%' THEN f.linear_mean_value ELSE NULL END), 2) AS recommend_score
FROM
    Fact_Patient_Survey f
INNER JOIN
    Dim_Survey_Details s ON f.survey_id = s.survey_id
INNER JOIN
    Dim_Hospital_Details hd ON f.hospital_id = hd.hospital_id
INNER JOIN
    Dim_Country_Details cd ON cd.Country_Id = f.country_id 
WHERE
    f.linear_mean_value IS NOT NULL AND f.linear_mean_value > 0
GROUP BY
    f.hospital_id, hd.hospital_name
HAVING
    SUM(f.number_of_completed_surveys) >= 100;

.output stdout

SELECT CURRENT_DIRECTORY();

PRAGMA table_info(Dim_Hospital_Details);

.mode csv
.headers on
.output hospital_linear_scores_with_zip.csv

SELECT
    f.hospital_id,
    hd.hospital_name,
    c.Zipcode AS zip_code,
    s.survey_question,
     ROUND(AVG(CASE WHEN s.survey_question LIKE '%Nurse communication - linear mean score%' THEN f.linear_mean_value ELSE NULL END), 2) AS nurse_score,
    ROUND(AVG(CASE WHEN s.survey_question LIKE '%Cleanliness - linear mean score%' THEN f.linear_mean_value ELSE NULL END), 2) AS clean_score,
    ROUND(AVG(CASE WHEN s.survey_question LIKE '%Doctor communication - linear mean score%' THEN f.linear_mean_value ELSE NULL END), 2) AS doctor_score,
    ROUND(AVG(CASE WHEN s.survey_question LIKE '%Staff responsiveness - linear mean score%' THEN f.linear_mean_value ELSE NULL END), 2) AS staff_score,
    ROUND(AVG(CASE WHEN s.survey_question LIKE '%Quietness - linear mean score%' THEN f.linear_mean_value ELSE NULL END), 2) AS quiet_score,
    ROUND(AVG(CASE WHEN s.survey_question LIKE '%Communication about medicines - linear mean score%' THEN f.linear_mean_value ELSE NULL END), 2) AS med_communication_score,
    ROUND(AVG(CASE WHEN s.survey_question LIKE '%Discharge information - linear mean score%' THEN f.linear_mean_value ELSE NULL END), 2) AS discharge_score,
    ROUND(AVG(CASE WHEN s.survey_question LIKE '%Care transition - linear mean score%' THEN f.linear_mean_value ELSE NULL END), 2) AS care_transition_score,
    ROUND(AVG(CASE WHEN s.survey_question LIKE '%Overall hospital rating - linear mean score%' THEN f.linear_mean_value ELSE NULL END), 2) AS overall_score,
    ROUND(AVG(CASE WHEN s.survey_question LIKE '%Recommend hospital - linear mean score%' THEN f.linear_mean_value ELSE NULL END), 2) AS recommend_score
FROM
    Fact_Patient_Survey f
JOIN
    Dim_Survey_Details s ON f.survey_id = s.survey_id
JOIN
    Dim_Hospital_Details hd ON f.hospital_id = hd.hospital_id
JOIN
    Dim_Country_Details c ON f.country_id = c.country_id
WHERE
    f.linear_mean_value IS NOT NULL
    AND s.survey_question LIKE '%linear mean score%'
GROUP BY
    f.hospital_id,
    hd.hospital_name,
    c.Zipcode,
    s.survey_question
HAVING
    SUM(f.number_of_completed_surveys) >= 100;

.output stdout


.output stdout


SELECT 
    overall_score,predicted_score,residual,performance
FROM   
    hospital_performance_cleaned
ORDER BY 
    residual DESC
LIMIT 20