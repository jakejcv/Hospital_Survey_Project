
import pandas as pd
import statsmodels.api as sm

# 1. Load your exported CSV
df = pd.read_csv('hospital_score_correlations.csv')

# 2. Select relevant columns
features = ['nurse_score', 'doctor_score', 'staff_score', 'clean_score', 'quiet_score']
target = 'overall_score'

# 3. Drop rows with missing data
df_clean = df.dropna(subset=features + [target])

# 4. Build a linear regression model
X = df_clean[features]
X = sm.add_constant(X)  # Adds intercept
y = df_clean[target]
model = sm.OLS(y, X).fit()

# 5. Predict expected overall scores
df_clean['expected_overall_score'] = model.predict(X)

# 6. Calculate difference
df_clean['performance_diff'] = df_clean[target] - df_clean['expected_overall_score']

# 7. Label over/underperformers with a threshold (e.g., ±2 points)
threshold = 2
df_clean['performance_label'] = df_clean['performance_diff'].apply(
    lambda x: 'Overperforming' if x > threshold else ('Underperforming' if x < -threshold else 'As Expected')
)

# 8. Save the results for Tableau visualization or CSV review
df_clean.to_csv('hospital_over_underperformance.csv', index=False)

# 9. Display top 10 over/underperformers
print("Top Overperformers:")
print(df_clean.sort_values('performance_diff', ascending=False)[['hospital_name', 'state', 'overall_score', 'expected_overall_score', 'performance_diff']].head(10))

print("\nTop Underperformers:")
print(df_clean.sort_values('performance_diff')[['hospital_name', 'state', 'overall_score', 'expected_overall_score', 'performance_diff']].head(10))
