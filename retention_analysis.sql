-- =====================================================
-- User Retention Analysis
-- Calculates retention rates across 7-day intervals
-- =====================================================

-- Retention rate calculation with 7-day intervals
WITH 
day0 AS (
  SELECT 
    COUNT(id) AS day0,
    created_date
  FROM user_info
  GROUP BY created_date
),

day1 AS (
  SELECT 
    COUNT(id) AS day1,
    created_date
  FROM user_info
  WHERE IFNULL(
    TIMESTAMP_DIFF(last_login, created_date, DAY),
    TIMESTAMP_DIFF(PARSE_DATE('%Y-%m-%d', '2023-04-01'), created_date, DAY)
  ) <= 7
  GROUP BY created_date
),

day2 AS (
  SELECT 
    COUNT(id) AS day2,
    created_date
  FROM user_info
  WHERE IFNULL(
    TIMESTAMP_DIFF(last_login, created_date, DAY),
    TIMESTAMP_DIFF(PARSE_DATE('%Y-%m-%d', '2023-04-01'), created_date, DAY)
  ) <= 14
  GROUP BY created_date
),

day3 AS (
  SELECT 
    COUNT(id) AS day3,
    created_date
  FROM user_info
  WHERE IFNULL(
    TIMESTAMP_DIFF(last_login, created_date, DAY),
    TIMESTAMP_DIFF(PARSE_DATE('%Y-%m-%d', '2023-04-01'), created_date, DAY)
  ) <= 21
  GROUP BY created_date
),

day4 AS (
  SELECT 
    COUNT(id) AS day4,
    created_date
  FROM user_info
  WHERE IFNULL(
    TIMESTAMP_DIFF(last_login, created_date, DAY),
    TIMESTAMP_DIFF(PARSE_DATE('%Y-%m-%d', '2023-04-01'), created_date, DAY)
  ) <= 28
  GROUP BY created_date
),

day5 AS (
  SELECT 
    COUNT(id) AS day5,
    created_date
  FROM user_info
  WHERE IFNULL(
    TIMESTAMP_DIFF(last_login, created_date, DAY),
    TIMESTAMP_DIFF(PARSE_DATE('%Y-%m-%d', '2023-04-01'), created_date, DAY)
  ) <= 35
  GROUP BY created_date
),

day6 AS (
  SELECT 
    COUNT(id) AS day6,
    created_date
  FROM user_info
  WHERE IFNULL(
    TIMESTAMP_DIFF(last_login, created_date, DAY),
    TIMESTAMP_DIFF(PARSE_DATE('%Y-%m-%d', '2023-04-01'), created_date, DAY)
  ) <= 42
  GROUP BY created_date
),

day7 AS (
  SELECT 
    COUNT(id) AS day7,
    created_date
  FROM user_info
  WHERE IFNULL(
    TIMESTAMP_DIFF(last_login, created_date, DAY),
    TIMESTAMP_DIFF(PARSE_DATE('%Y-%m-%d', '2023-04-01'), created_date, DAY)
  ) <= 49
  GROUP BY created_date
)

SELECT 
  day0.created_date,
  day0.day0 / day0.day0 AS day0_retention,
  CONCAT(
    ROUND((COALESCE((day0.day0 - day1.day1), day0.day0) / day0.day0 * 100), 2), 
    '%'
  ) AS day1_retention,
  CONCAT(
    ROUND((COALESCE((day0.day0 - day2.day2), day0.day0) / day0.day0 * 100), 2), 
    '%'
  ) AS day2_retention,
  CONCAT(
    ROUND((COALESCE((day0.day0 - day3.day3), day0.day0) / day0.day0 * 100), 2), 
    '%'
  ) AS day3_retention,
  CONCAT(
    ROUND((COALESCE((day0.day0 - day4.day4), day0.day0) / day0.day0 * 100), 2), 
    '%'
  ) AS day4_retention,
  CONCAT(
    ROUND((COALESCE((day0.day0 - day5.day5), day0.day0) / day0.day0 * 100), 2), 
    '%'
  ) AS day5_retention,
  CONCAT(
    ROUND((COALESCE((day0.day0 - day6.day6), day0.day0) / day0.day0 * 100), 2), 
    '%'
  ) AS day6_retention,
  CONCAT(
    ROUND((COALESCE((day0.day0 - day7.day7), day0.day0) / day0.day0 * 100), 2), 
    '%'
  ) AS day7_retention
FROM day0
LEFT JOIN day1 USING (created_date)
LEFT JOIN day2 USING (created_date)
LEFT JOIN day3 USING (created_date)
LEFT JOIN day4 USING (created_date)
LEFT JOIN day5 USING (created_date)
LEFT JOIN day6 USING (created_date)
LEFT JOIN day7 USING (created_date)
ORDER BY day0.created_date;

-- Cohort retention summary
WITH retention_summary AS (
  SELECT 
    EXTRACT(YEAR FROM created_date) AS year,
    EXTRACT(MONTH FROM created_date) AS month,
    COUNT(*) AS cohort_size,
    COUNT(CASE WHEN last_login >= DATE_ADD(created_date, INTERVAL 7 DAY) THEN 1 END) AS retained_7d,
    COUNT(CASE WHEN last_login >= DATE_ADD(created_date, INTERVAL 14 DAY) THEN 1 END) AS retained_14d,
    COUNT(CASE WHEN last_login >= DATE_ADD(created_date, INTERVAL 30 DAY) THEN 1 END) AS retained_30d
  FROM user_info
  WHERE created_date IS NOT NULL
  GROUP BY EXTRACT(YEAR FROM created_date), EXTRACT(MONTH FROM created_date)
)
SELECT 
  year,
  month,
  cohort_size,
  ROUND(retained_7d * 100.0 / cohort_size, 2) AS retention_7d_pct,
  ROUND(retained_14d * 100.0 / cohort_size, 2) AS retention_14d_pct,
  ROUND(retained_30d * 100.0 / cohort_size, 2) AS retention_30d_pct
FROM retention_summary
ORDER BY year, month;

-- Platform-specific retention analysis
SELECT 
  ui.platform,
  COUNT(*) AS total_users,
  COUNT(CASE WHEN TIMESTAMP_DIFF(last_login, created_date, DAY) >= 7 THEN 1 END) AS retained_7d,
  COUNT(CASE WHEN TIMESTAMP_DIFF(last_login, created_date, DAY) >= 14 THEN 1 END) AS retained_14d,
  COUNT(CASE WHEN TIMESTAMP_DIFF(last_login, created_date, DAY) >= 30 THEN 1 END) AS retained_30d,
  ROUND(COUNT(CASE WHEN TIMESTAMP_DIFF(last_login, created_date, DAY) >= 7 THEN 1 END) * 100.0 / COUNT(*), 2) AS retention_7d_pct,
  ROUND(COUNT(CASE WHEN TIMESTAMP_DIFF(last_login, created_date, DAY) >= 14 THEN 1 END) * 100.0 / COUNT(*), 2) AS retention_14d_pct,
  ROUND(COUNT(CASE WHEN TIMESTAMP_DIFF(last_login, created_date, DAY) >= 30 THEN 1 END) * 100.0 / COUNT(*), 2) AS retention_30d_pct
FROM user_info ui
WHERE ui.platform IS NOT NULL
  AND ui.last_login IS NOT NULL
  AND ui.created_date IS NOT NULL
GROUP BY ui.platform
ORDER BY retention_30d_pct DESC;