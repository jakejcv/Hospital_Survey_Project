import pandas as pd

# Load your exported hospital-level scores
df = pd.read_csv('hospital_linear_scores_v5.csv')

# Select relevant columns for correlation
correlation_columns = [
    'Overall Score',
    'Clean Score',
    'Doctor Score',
    'Nurse Score',
    'Quiet Score',
    'Staff Score',
    'Recommend Score',
    'Care Transition Score',
    'Discharge Score',
    'Med Communication Score'
]

# Compute correlation matrix
correlation_matrix = df[correlation_columns].corr(method='pearson')

# Display correlation of each variable with Overall Score, sorted
overall_corr = correlation_matrix['Overall Score'].sort_values(ascending=False)
print(overall_corr)

# Optional: Save to CSV
correlation_matrix.to_csv('hospital_score_correlations.csv', index=True)
