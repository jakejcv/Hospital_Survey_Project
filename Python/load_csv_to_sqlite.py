import pandas as pd
import sqlite3

# Load the CSV
df = pd.read_csv("Health Care_Patient_survey_source.csv")  # update if your file name is different

# Connect to SQLite DB (creates it if not present)
conn = sqlite3.connect("survey_project.sqlite")

# Load the DataFrame into a table
df.to_sql("Raw_Survey_Data", conn, if_exists="replace", index=False)

print("✅ CSV loaded into SQLite!")

conn.close()
