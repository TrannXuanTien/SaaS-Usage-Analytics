-- =====================================================
-- Geographic Analysis
-- User distribution and behavior patterns by country
-- =====================================================

-- Create customer geography table
CREATE TABLE number_customer_country AS (
  SELECT 
    ui.user_id AS user_id,
    mp_country_code AS country_code, 
    g.country AS country, 
    g.latitude,
    g.longitude
  FROM user_info AS ui
  JOIN geography AS g ON ui.mp_country_code = g.code
);

-- Top countries by user count
SELECT 
  country,
  COUNT(user_id) AS number_customers,
  ROUND(COUNT(user_id) * 100.0 / SUM(COUNT(user_id)) OVER(), 2) AS percentage
FROM number_customer_country
GROUP BY country
ORDER BY number_customers DESC
LIMIT 15;

-- Geographic revenue analysis
WITH country_revenue AS (
  SELECT 
    ncc.country,
    ncc.country_code,
    COUNT(DISTINCT ncc.user_id) AS total_users,
    COUNT(DISTINCT e.user_id) AS active_users,
    COALESCE(SUM(e.fee), 0) AS total_revenue,
    COALESCE(SUM(e.volume), 0) AS total_volume,
    COUNT(e.id) AS total_events
  FROM number_customer_country ncc
  LEFT JOIN events e ON ncc.user_id = e.user_id
  GROUP BY ncc.country, ncc.country_code
)
SELECT 
  country,
  total_users,
  active_users,
  ROUND(active_users * 100.0 / total_users, 2) AS activation_rate,
  ROUND(total_revenue, 2) AS total_revenue,
  ROUND(total_revenue / NULLIF(active_users, 0), 2) AS revenue_per_active_user,
  ROUND(total_volume / NULLIF(active_users, 0), 2) AS volume_per_active_user,
  ROUND(total_events / NULLIF(active_users, 0), 2) AS events_per_active_user
FROM country_revenue
WHERE total_users >= 10
ORDER BY total_revenue DESC;

-- Platform preference by country
SELECT 
  ncc.country,
  ui.platform,
  COUNT(*) AS users,
  ROUND(COUNT(*) * 100.0 / SUM(COUNT(*)) OVER(PARTITION BY ncc.country), 2) AS platform_share
FROM number_customer_country ncc
JOIN user_info ui ON ncc.user_id = ui.user_id
WHERE ui.platform IS NOT NULL
GROUP BY ncc.country, ui.platform
HAVING COUNT(*) >= 5
ORDER BY ncc.country, users DESC;

-- Operating system distribution by top countries
WITH top_countries AS (
  SELECT country
  FROM number_customer_country
  GROUP BY country
  ORDER BY COUNT(user_id) DESC
  LIMIT 10
)
SELECT 
  ncc.country,
  ui.os,
  COUNT(*) AS users,
  ROUND(COUNT(*) * 100.0 / SUM(COUNT(*)) OVER(PARTITION BY ncc.country), 2) AS os_share
FROM number_customer_country ncc
JOIN user_info ui ON ncc.user_id = ui.user_id
JOIN top_countries tc ON ncc.country = tc.country
WHERE ui.os IS NOT NULL
GROUP BY ncc.country, ui.os
ORDER BY ncc.country, users DESC;

-- User engagement patterns by region
WITH country_engagement AS (
  SELECT 
    ncc.country,
    ui.user_id,
    ui.created_date,
    ui.last_login,
    TIMESTAMP_DIFF(COALESCE(ui.last_login, DATE('2023-04-01')), ui.created_date, DAY) AS user_lifespan_days,
    COUNT(e.id) AS total_events,
    SUM(e.volume) AS total_volume,
    SUM(e.fee) AS total_fee
  FROM number_customer_country ncc
  JOIN user_info ui ON ncc.user_id = ui.user_id
  LEFT JOIN events e ON ui.user_id = e.user_id
  GROUP BY ncc.country, ui.user_id, ui.created_date, ui.last_login
)
SELECT 
  country,
  COUNT(*) AS total_users,
  ROUND(AVG(user_lifespan_days), 1) AS avg_user_lifespan_days,
  ROUND(AVG(total_events), 1) AS avg_events_per_user,
  ROUND(AVG(total_volume), 1) AS avg_volume_per_user,
  ROUND(AVG(total_fee), 2) AS avg_revenue_per_user,
  COUNT(CASE WHEN total_events > 0 THEN 1 END) AS engaged_users,
  ROUND(COUNT(CASE WHEN total_events > 0 THEN 1 END) * 100.0 / COUNT(*), 2) AS engagement_rate
FROM country_engagement
GROUP BY country
HAVING COUNT(*) >= 20
ORDER BY avg_revenue_per_user DESC;

-- Seasonal usage patterns by top countries
SELECT 
  ncc.country,
  EXTRACT(MONTH FROM e.date) AS month,
  COUNT(DISTINCT e.user_id) AS active_users,
  COUNT(e.id) AS total_events,
  SUM(e.volume) AS total_volume,
  SUM(e.fee) AS total_revenue
FROM number_customer_country ncc
JOIN events e ON ncc.user_id = e.user_id
WHERE ncc.country IN (
  SELECT country
  FROM number_customer_country
  GROUP BY country
  ORDER BY COUNT(user_id) DESC
  LIMIT 5
)
GROUP BY ncc.country, EXTRACT(MONTH FROM e.date)
ORDER BY ncc.country, month;

-- Geographic clustering analysis
WITH country_metrics AS (
  SELECT 
    ncc.country,
    g.latitude,
    g.longitude,
    COUNT(DISTINCT ncc.user_id) AS user_count,
    AVG(TIMESTAMP_DIFF(COALESCE(ui.last_login, DATE('2023-04-01')), ui.created_date, DAY)) AS avg_retention_days,
    COALESCE(SUM(e.fee), 0) / COUNT(DISTINCT ncc.user_id) AS revenue_per_user,
    COUNT(CASE WHEN TIMESTAMP_DIFF(COALESCE(ui.last_login, DATE('2023-04-01')), ui.created_date, DAY) <= 3 THEN 1 END) AS trial_abuse_users
  FROM number_customer_country ncc
  JOIN geography g ON ncc.country_code = g.code
  JOIN user_info ui ON ncc.user_id = ui.user_id
  LEFT JOIN events e ON ncc.user_id = e.user_id
  GROUP BY ncc.country, g.latitude, g.longitude
  HAVING COUNT(DISTINCT ncc.user_id) >= 10
)
SELECT 
  country,
  latitude,
  longitude,
  user_count,
  ROUND(avg_retention_days, 1) AS avg_retention_days,
  ROUND(revenue_per_user, 2) AS revenue_per_user,
  trial_abuse_users,
  ROUND(trial_abuse_users * 100.0 / user_count, 2) AS abuse_rate,
  CASE 
    WHEN revenue_per_user > 10 AND avg_retention_days > 30 THEN 'High Value'
    WHEN revenue_per_user > 5 OR avg_retention_days > 20 THEN 'Medium Value'
    WHEN trial_abuse_users / user_count > 0.2 THEN 'High Risk'
    ELSE 'Standard'
  END AS market_classification
FROM country_metrics
ORDER BY revenue_per_user DESC;

-- Time zone analysis (approximated by longitude)
WITH timezone_approx AS (
  SELECT 
    ncc.country,
    ncc.user_id,
    g.longitude,
    CASE 
      WHEN g.longitude BETWEEN -180 AND -120 THEN 'UTC-8 to UTC-11'
      WHEN g.longitude BETWEEN -120 AND -60 THEN 'UTC-4 to UTC-8'
      WHEN g.longitude BETWEEN -60 AND 0 THEN 'UTC-0 to UTC-4'
      WHEN g.longitude BETWEEN 0 AND 60 THEN 'UTC+0 to UTC+4'
      WHEN g.longitude BETWEEN 60 AND 120 THEN 'UTC+4 to UTC+8'
      WHEN g.longitude BETWEEN 120 AND 180 THEN 'UTC+8 to UTC+12'
      ELSE 'Unknown'
    END AS timezone_region,
    COUNT(e.id) AS events,
    SUM(e.fee) AS revenue
  FROM number_customer_country ncc
  JOIN geography g ON ncc.country_code = g.code
  LEFT JOIN events e ON ncc.user_id = e.user_id
  GROUP BY ncc.country, ncc.user_id, g.longitude
)
SELECT 
  timezone_region,
  COUNT(DISTINCT user_id) AS users,
  SUM(events) AS total_events,
  ROUND(SUM(revenue), 2) AS total_revenue,
  ROUND(AVG(events), 1) AS avg_events_per_user,
  ROUND(AVG(revenue), 2) AS avg_revenue_per_user
FROM timezone_approx
WHERE timezone_region != 'Unknown'
GROUP BY timezone_region
ORDER BY total_revenue DESC;