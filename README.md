Hospital Survey Analytics Project
Overview

This project is an end-to-end analytics pipeline built to analyze U.S. hospital patient experience survey data (HCAHPS-style metrics). The goal is to move beyond raw survey scores and identify relative hospital performance by modeling expected outcomes and analyzing over- and under-performance using regression residuals.

The project demonstrates real-world data cleaning, dimensional modeling, statistical analysis, and visualization — mirroring how analytics work is done in production environments.

Key Objectives

Clean and standardize raw patient survey data

Design dimension and fact tables for analysis

Model expected hospital performance using multiple survey dimensions

Identify hospitals that over- or under-perform relative to expectations

Prepare outputs for business-friendly visualization in Tableau

Tech Stack

Python: pandas, numpy, statsmodels

SQL: dimensional modeling, table creation

SQLite: lightweight analytics database

Tableau: dashboards and exploratory visualizations

Git/GitHub: version control and project organization

Project Structure
Hospital_Survey_Project/
│
├── Data/
│   ├── Raw Data/                # Original source CSV
│   └── Processed Data/          # Cleaned fact & dimension tables
│
├── Python/
│   ├── load_raw_survey_data.py
│   ├── export_fact_table.py
│   ├── compute_survey_correlations.py
│   └── load_csv_to_sqlite.py
│
├── SQL/
│   └── build_dimensions.sql
│
├── Tableau/
│   └── survey project graphs.twb
│
├── requirements.txt
├── README.md
└── .gitignore

Data Pipeline

Raw ingestion

Load raw hospital survey CSV data

Handle missing values, inconsistent data types, and invalid entries

Data cleaning & standardization

Convert string-based numeric fields to proper numeric types

Normalize survey scores and response counts

Remove or flag low-response hospitals where appropriate

Dimensional modeling

Create dimension tables (hospital, measure, survey, geography)

Build a centralized fact table for survey results

Statistical modeling

Fit a multivariate linear regression model to predict expected overall scores

Compute residuals to quantify over- and under-performance

Analytics outputs

Export cleaned datasets and model results

Visualize patterns and outliers in Tableau

Key Outputs

fact_survey.csv – centralized survey fact table

hospital_performance_cleaned.csv – modeled hospital performance with residuals

hospital_over_underperformance.csv – performance classification

survey project graphs.twb – Tableau workbook with dashboards

How to Run
# Create and activate virtual environment
python -m venv venv
source venv/bin/activate   # macOS/Linux
# or venv\Scripts\activate # Windows

# Install dependencies
pip install -r requirements.txt

# Run pipeline scripts
python Python/load_raw_survey_data.py
python Python/export_fact_table.py
python Python/compute_survey_correlations.py

Why This Project Matters

Rather than ranking hospitals by raw survey scores alone, this project focuses on expected vs. actual performance, a common real-world analytics requirement. By using regression residuals, the analysis highlights hospitals performing better or worse than predicted — a more nuanced and fair assessment approach.

This mirrors how analytics teams evaluate performance, risk, and quality in healthcare, insurance, and other regulated industries.

Notes

Source data is publicly available healthcare survey data

The project intentionally emphasizes data modeling and reasoning, not just visualization

All transformations are reproducible via scripts included in this repository

If you want, next we can:

Tighten this further for recruiter scanning

Add a short “Business Questions Answered” section

Or create a one-paragraph LinkedIn / resume project summary based on this README


