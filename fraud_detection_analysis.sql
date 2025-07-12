-- =====================================================
-- Fraud Detection & Cheater Analysis
-- Identifies users exploiting trial periods
-- =====================================================

-- Step 1: Identify users suspended within trial period (3 days)
WITH suspended_in_trial AS (
  SELECT * FROM (
    SELECT 
      id,
      user_id,
      mp_country_code,
      created_date,
      COALESCE(last_login, DATE('2023-04-01')) AS last_login,
      os
    FROM user_info
  ) a
  WHERE IFNULL(
    TIMESTAMP_DIFF(last_login, created_date, DAY),
    TIMESTAMP_DIFF(PARSE_DATE('%Y-%m-%d', '2023-03-01'), created_date, DAY)
  ) <= 3
),

-- Step 2: Find user_ids with multiple creations (same country + OS)
repeat_cheaters AS (
  SELECT 
    user_id,
    mp_country_code,
    os,
    COUNT(id) AS number_create
  FROM suspended_in_trial
  GROUP BY user_id, mp_country_code, os
  HAVING COUNT(id) > 5
    AND user_id IS NOT NULL
),

-- Step 3: Count serious cheaters by country
cheater_summary AS (
  SELECT 
    COUNT(*) AS cheater_count,
    g.country
  FROM repeat_cheaters rc
  JOIN geography_updated g ON rc.mp_country_code = g.code
  GROUP BY g.country
)

-- Final result: Countries with highest fraud risk
SELECT 
  country,
  cheater_count,
  RANK() OVER (ORDER BY cheater_count DESC) AS fraud_rank
FROM cheater_summary
ORDER BY cheater_count DESC;

-- Detailed cheater analysis
CREATE TABLE serious_cheaters AS (
  WITH trial_abuse AS (
    SELECT 
      user_id,
      mp_country_code,
      os,
      created_date,
      last_login,
      TIMESTAMP_DIFF(COALESCE(last_login, DATE('2023-04-01')), created_date, DAY) AS days_used
    FROM user_info
    WHERE TIMESTAMP_DIFF(COALESCE(last_login, DATE('2023-04-01')), created_date, DAY) <= 3
  ),
  
  cheater_patterns AS (
    SELECT 
      user_id,
      mp_country_code,
      os,
      COUNT(*) AS abuse_count,
      MIN(created_date) AS first_abuse,
      MAX(created_date) AS last_abuse,
      AVG(days_used) AS avg_days_used
    FROM trial_abuse
    GROUP BY user_id, mp_country_code, os
    HAVING COUNT(*) > 5
  )
  
  SELECT 
    cp.*,
    g.country,
    TIMESTAMP_DIFF(last_abuse, first_abuse, DAY) AS abuse_period_days
  FROM cheater_patterns cp
  JOIN geography_updated g ON cp.mp_country_code = g.code
);

-- Trial suspension patterns by region
SELECT 
  g.country,
  COUNT(DISTINCT ui.user_id) AS total_users,
  COUNT(CASE WHEN TIMESTAMP_DIFF(COALESCE(ui.last_login, DATE('2023-04-01')), ui.created_date, DAY) <= 3 THEN 1 END) AS early_suspensions,
  ROUND(
    COUNT(CASE WHEN TIMESTAMP_DIFF(COALESCE(ui.last_login, DATE('2023-04-01')), ui.created_date, DAY) <= 3 THEN 1 END) * 100.0 
    / COUNT(DISTINCT ui.user_id), 2
  ) AS early_suspension_rate
FROM user_info ui
JOIN geography g ON ui.mp_country_code = g.code
GROUP BY g.country
HAVING COUNT(DISTINCT ui.user_id) >= 100  -- Only countries with significant user base
ORDER BY early_suspension_rate DESC;

-- Platform-specific fraud patterns
SELECT 
  ui.platform,
  ui.os,
  COUNT(*) AS total_accounts,
  COUNT(CASE WHEN TIMESTAMP_DIFF(COALESCE(ui.last_login, DATE('2023-04-01')), ui.created_date, DAY) <= 3 THEN 1 END) AS suspicious_accounts,
  ROUND(
    COUNT(CASE WHEN TIMESTAMP_DIFF(COALESCE(ui.last_login, DATE('2023-04-01')), ui.created_date, DAY) <= 3 THEN 1 END) * 100.0 
    / COUNT(*), 2
  ) AS fraud_rate
FROM user_info ui
WHERE ui.platform IS NOT NULL AND ui.os IS NOT NULL
GROUP BY ui.platform, ui.os
ORDER BY fraud_rate DESC;

-- Time-based fraud analysis
SELECT 
  EXTRACT(YEAR FROM created_date) AS year,
  EXTRACT(MONTH FROM created_date) AS month,
  COUNT(*) AS total_registrations,
  COUNT(CASE WHEN TIMESTAMP_DIFF(COALESCE(last_login, DATE('2023-04-01')), created_date, DAY) <= 3 THEN 1 END) AS trial_abuse_cases,
  ROUND(
    COUNT(CASE WHEN TIMESTAMP_DIFF(COALESCE(last_login, DATE('2023-04-01')), created_date, DAY) <= 3 THEN 1 END) * 100.0 
    / COUNT(*), 2
  ) AS abuse_rate
FROM user_info
WHERE created_date IS NOT NULL
GROUP BY EXTRACT(YEAR FROM created_date), EXTRACT(MONTH FROM created_date)
ORDER BY year, month;

-- User behavior anomaly detection
WITH user_stats AS (
  SELECT 
    ui.user_id,
    ui.mp_country_code,
    ui.os,
    COUNT(*) AS account_count,
    MIN(ui.created_date) AS first_account,
    MAX(ui.created_date) AS latest_account,
    AVG(TIMESTAMP_DIFF(COALESCE(ui.last_login, DATE('2023-04-01')), ui.created_date, DAY)) AS avg_usage_days
  FROM user_info ui
  GROUP BY ui.user_id, ui.mp_country_code, ui.os
)
SELECT 
  user_id,
  mp_country_code,
  os,
  account_count,
  TIMESTAMP_DIFF(latest_account, first_account, DAY) AS account_span_days,
  ROUND(avg_usage_days, 2) AS avg_usage_days,
  CASE 
    WHEN account_count > 10 THEN 'Extreme Risk'
    WHEN account_count > 5 THEN 'High Risk'
    WHEN account_count > 2 AND avg_usage_days < 7 THEN 'Medium Risk'
    ELSE 'Low Risk'
  END AS fraud_risk_level
FROM user_stats
WHERE account_count > 1
ORDER BY account_count DESC, avg_usage_days ASC;