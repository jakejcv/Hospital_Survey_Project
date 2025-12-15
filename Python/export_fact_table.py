import pandas as pd
import sqlite3

# Connect to the SQLite database
conn = sqlite3.connect("survey_project.sqlite")

# Read the Fact_Patient_Survey table
df = pd.read_sql_query("SELECT * FROM Fact_Patient_Survey", conn)

# Export to CSV
df.to_csv("fact_survey.csv", index=False)

conn.close()
print("✅ Export complete: fact_survey.csv")

