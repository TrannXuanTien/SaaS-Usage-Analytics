-- =====================================================
-- Business Metrics & KPIs
-- Key performance indicators for business monitoring
-- =====================================================

-- Daily Active Users (DAU) by Platform
WITH daily_metrics AS (
  SELECT 
    date,
    platform,
    COUNT(DISTINCT user_id) AS dau,
    COUNT(*) AS total_events,
    SUM(volume) AS daily_volume,
    SUM(fee) AS daily_revenue
  FROM events
  GROUP BY date, platform
)
SELECT 
  date,
  SUM(CASE WHEN platform = 'web' THEN dau ELSE 0 END) AS web_dau,
  SUM(CASE WHEN platform = 'android' THEN dau ELSE 0 END) AS android_dau,
  SUM(CASE WHEN platform = 'ios' THEN dau ELSE 0 END) AS ios_dau,
  SUM(dau) AS total_dau,
  SUM(daily_revenue) AS total_daily_revenue,
  SUM(daily_volume) AS total_daily_volume
FROM daily_metrics
GROUP BY date
ORDER BY date;

-- Monthly Active Users (MAU) and Growth Rates
WITH monthly_metrics AS (
  SELECT 
    EXTRACT(YEAR FROM date) AS year,
    EXTRACT(MONTH FROM date) AS month,
    COUNT(DISTINCT user_id) AS mau,
    SUM(fee) AS monthly_revenue,
    SUM(volume) AS monthly_volume
  FROM events
  GROUP BY EXTRACT(YEAR FROM date), EXTRACT(MONTH FROM date)
),
monthly_growth AS (
  SELECT 
    year,
    month,
    mau,
    monthly_revenue,
    monthly_volume,
    LAG(mau) OVER (ORDER BY year, month) AS prev_mau,
    LAG(monthly_revenue) OVER (ORDER BY year, month) AS prev_revenue
  FROM monthly_metrics
)
SELECT 
  year,
  month,
  mau,
  ROUND(monthly_revenue, 2) AS monthly_revenue,
  ROUND(monthly_volume, 0) AS monthly_volume,
  CASE 
    WHEN prev_mau IS NOT NULL THEN ROUND((mau - prev_mau) * 100.0 / prev_mau, 2)
    ELSE NULL 
  END AS mau_growth_rate,
  CASE 
    WHEN prev_revenue IS NOT NULL THEN ROUND((monthly_revenue - prev_revenue) * 100.0 / prev_revenue, 2)
    ELSE NULL 
  END AS revenue_growth_rate
FROM monthly_growth
ORDER BY year, month;

-- Customer Acquisition Metrics
WITH acquisition_metrics AS (
  SELECT 
    DATE_TRUNC(created_date, MONTH) AS acquisition_month,
    COUNT(*) AS new_users,
    COUNT(CASE WHEN platform = 'web' THEN 1 END) AS web_acquisitions,
    COUNT(CASE WHEN platform = 'android' THEN 1 END) AS android_acquisitions,
    COUNT(CASE WHEN platform = 'ios' THEN 1 END) AS ios_acquisitions
  FROM user_info
  WHERE created_date IS NOT NULL
  GROUP BY DATE_TRUNC(created_date, MONTH)
)
SELECT 
  acquisition_month,
  new_users,
  web_acquisitions,
  android_acquisitions,
  ios_acquisitions,
  ROUND(web_acquisitions * 100.0 / new_users, 1) AS web_acquisition_rate,
  ROUND(android_acquisitions * 100.0 / new_users, 1) AS android_acquisition_rate,
  ROUND(ios_acquisitions * 100.0 / new_users, 1) AS ios_acquisition_rate
FROM acquisition_metrics
ORDER BY acquisition_month;

-- Revenue Metrics
WITH revenue_analysis AS (
  SELECT 
    COUNT(DISTINCT e.user_id) AS paying_users,
    COUNT(DISTINCT ui.user_id) AS total_users,
    SUM(e.fee) AS total_revenue,
    AVG(e.fee) AS avg_transaction_value,
    PERCENTILE_CONT(e.fee, 0.5) OVER() AS median_transaction_value,
    COUNT(e.id) AS total_transactions
  FROM user_info ui
  LEFT JOIN events e ON ui.user_id = e.user_id
)
SELECT 
  total_users,
  paying_users,
  ROUND(paying_users * 100.0 / total_users, 2) AS conversion_rate,
  ROUND(total_revenue, 2) AS total_revenue,
  ROUND(total_revenue / paying_users, 2) AS arpu,  -- Average Revenue Per User
  ROUND(avg_transaction_value, 2) AS avg_transaction_value,
  ROUND(median_transaction_value, 2) AS median_transaction_value,
  total_transactions,
  ROUND(total_transactions / paying_users, 2) AS avg_transactions_per_user
FROM revenue_analysis;

-- Feature Usage Analysis
WITH feature_usage AS (
  SELECT 
    ui.feature,
    COUNT(DISTINCT ui.user_id) AS users_with_feature,
    COUNT(DISTINCT e.user_id) AS active_users_with_feature,
    COALESCE(SUM(e.fee), 0) AS revenue_from_feature,
    COUNT(e.id) AS events_from_feature
  FROM user_info ui
  LEFT JOIN events e ON ui.user_id = e.user_id
  WHERE ui.feature IS NOT NULL
  GROUP BY ui.feature
)
SELECT 
  feature,
  users_with_feature,
  active_users_with_feature,
  ROUND(active_users_with_feature * 100.0 / users_with_feature, 2) AS feature_activation_rate,
  ROUND(revenue_from_feature, 2) AS feature_revenue,
  ROUND(revenue_from_feature / NULLIF(active_users_with_feature, 0), 2) AS revenue_per_active_user,
  events_from_feature,
  ROUND(events_from_feature / NULLIF(active_users_with_feature, 0), 2) AS events_per_active_user
FROM feature_usage
ORDER BY feature_revenue DESC;

-- User Engagement Metrics
WITH engagement_metrics AS (
  SELECT 
    e.user_id,
    COUNT(DISTINCT DATE(e.datetime)) AS active_days,
    COUNT(e.id) AS total_events,
    SUM(e.volume) AS total_volume,
    SUM(e.fee) AS total_revenue,
    MIN(e.datetime) AS first_event,
    MAX(e.datetime) AS last_event,
    TIMESTAMP_DIFF(MAX(e.datetime), MIN(e.datetime), DAY) + 1 AS user_lifetime_days
  FROM events e
  GROUP BY e.user_id
)
SELECT 
  CASE 
    WHEN total_events >= 100 THEN 'Power Users (100+ events)'
    WHEN total_events >= 50 THEN 'High Users (50-99 events)'
    WHEN total_events >= 20 THEN 'Medium Users (20-49 events)'
    WHEN total_events >= 5 THEN 'Low Users (5-19 events)'
    ELSE 'Minimal Users (1-4 events)'
  END AS user_segment,
  COUNT(*) AS user_count,
  ROUND(AVG(active_days), 1) AS avg_active_days,
  ROUND(AVG(total_events), 1) AS avg_total_events,
  ROUND(AVG(total_volume), 1) AS avg_total_volume,
  ROUND(AVG(total_revenue), 2) AS avg_total_revenue,
  ROUND(AVG(user_lifetime_days), 1) AS avg_lifetime_days,
  ROUND(AVG(active_days * 1.0 / NULLIF(user_lifetime_days, 0)), 3) AS avg_engagement_ratio
FROM engagement_metrics
GROUP BY 
  CASE 
    WHEN total_events >= 100 THEN 'Power Users (100+ events)'
    WHEN total_events >= 50 THEN 'High Users (50-99 events)'
    WHEN total_events >= 20 THEN 'Medium Users (20-49 events)'
    WHEN total_events >= 5 THEN 'Low Users (5-19 events)'
    ELSE 'Minimal Users (1-4 events)'
  END
ORDER BY avg_total_revenue DESC;

-- Churn Analysis
WITH user_activity AS (
  SELECT 
    ui.user_id,
    ui.created_date,
    ui.last_login,
    ui.platform,
    TIMESTAMP_DIFF(COALESCE(ui.last_login, DATE('2023-04-01')), ui.created_date, DAY) AS days_active,
    TIMESTAMP_DIFF(DATE('2023-04-01'), COALESCE(ui.last_login, ui.created_date), DAY) AS days_since_last_activity,
    COUNT(e.id) AS total_events,
    SUM(e.fee) AS total_revenue
  FROM user_info ui
  LEFT JOIN events e ON ui.user_id = e.user_id
  GROUP BY ui.user_id, ui.created_date, ui.last_login, ui.platform
),
churn_classification AS (
  SELECT 
    *,
    CASE 
      WHEN days_since_last_activity <= 7 THEN 'Active'
      WHEN days_since_last_activity <= 30 THEN 'At Risk'
      WHEN days_since_last_activity <= 90 THEN 'Dormant'
      ELSE 'Churned'
    END AS churn_status
  FROM user_activity
)
SELECT 
  churn_status,
  platform,
  COUNT(*) AS user_count,
  ROUND(COUNT(*) * 100.0 / SUM(COUNT(*)) OVER(), 2) AS percentage,
  ROUND(AVG(days_active), 1) AS avg_days_active,
  ROUND(AVG(total_events), 1) AS avg_events,
  ROUND(AVG(total_revenue), 2) AS avg_revenue
FROM churn_classification
WHERE platform IS NOT NULL
GROUP BY churn_status, platform
ORDER BY 
  CASE churn_status 
    WHEN 'Active' THEN 1 
    WHEN 'At Risk' THEN 2 
    WHEN 'Dormant' THEN 3 
    WHEN 'Churned' THEN 4 
  END,
  platform;

-- Platform Performance Comparison
WITH platform_metrics AS (
  SELECT 
    ui.platform,
    COUNT(DISTINCT ui.user_id) AS total_users,
    COUNT(DISTINCT CASE WHEN e.user_id IS NOT NULL THEN ui.user_id END) AS active_users,
    COUNT(e.id) AS total_events,
    SUM(e.fee) AS total_revenue,
    SUM(e.volume) AS total_volume,
    AVG(TIMESTAMP_DIFF(COALESCE(ui.last_login, DATE('2023-04-01')), ui.created_date, DAY)) AS avg_user_lifetime
  FROM user_info ui
  LEFT JOIN events e ON ui.user_id = e.user_id
  WHERE ui.platform IS NOT NULL
  GROUP BY ui.platform
)
SELECT 
  platform,
  total_users,
  active_users,
  ROUND(active_users * 100.0 / total_users, 2) AS activation_rate,
  total_events,
  ROUND(total_revenue, 2) AS total_revenue,
  ROUND(total_volume, 0) AS total_volume,
  ROUND(total_revenue / NULLIF(active_users, 0), 2) AS revenue_per_active_user,
  ROUND(total_events / NULLIF(active_users, 0), 2) AS events_per_active_user,
  ROUND(avg_user_lifetime, 1) AS avg_user_lifetime_days,
  ROUND(total_revenue / total_users, 2) AS revenue_per_total_user
FROM platform_metrics
ORDER BY total_revenue DESC;

-- Weekly Trends Analysis
WITH weekly_trends AS (
  SELECT 
    DATE_TRUNC(date, WEEK(MONDAY)) AS week_start,
    COUNT(DISTINCT user_id) AS weekly_active_users,
    COUNT(*) AS weekly_events,
    SUM(fee) AS weekly_revenue,
    SUM(volume) AS weekly_volume
  FROM events
  GROUP BY DATE_TRUNC(date, WEEK(MONDAY))
)
SELECT 
  week_start,
  weekly_active_users,
  weekly_events,
  ROUND(weekly_revenue, 2) AS weekly_revenue,
  ROUND(weekly_volume, 0) AS weekly_volume,
  LAG(weekly_active_users) OVER (ORDER BY week_start) AS prev_week_users,
  ROUND(
    (weekly_active_users - LAG(weekly_active_users) OVER (ORDER BY week_start)) * 100.0 
    / NULLIF(LAG(weekly_active_users) OVER (ORDER BY week_start), 0), 2
  ) AS user_growth_rate,
  ROUND(weekly_revenue / NULLIF(weekly_active_users, 0), 2) AS revenue_per_user_weekly
FROM weekly_trends
ORDER BY week_start;

-- Customer Lifetime Value (CLV) Analysis
WITH user_clv AS (
  SELECT 
    ui.user_id,
    ui.platform,
    ui.created_date,
    ui.last_login,
    TIMESTAMP_DIFF(COALESCE(ui.last_login, DATE('2023-04-01')), ui.created_date, DAY) AS lifetime_days,
    COUNT(e.id) AS total_transactions,
    COALESCE(SUM(e.fee), 0) AS total_revenue,
    COALESCE(SUM(e.volume), 0) AS total_volume
  FROM user_info ui
  LEFT JOIN events e ON ui.user_id = e.user_id
  GROUP BY ui.user_id, ui.platform, ui.created_date, ui.last_login
),
clv_segments AS (
  SELECT 
    *,
    CASE 
      WHEN total_revenue >= 100 THEN 'High Value (100+)'
      WHEN total_revenue >= 50 THEN 'Medium Value (50-99)'
      WHEN total_revenue >= 10 THEN 'Low Value (10-49)'
      WHEN total_revenue > 0 THEN 'Minimal Value (0-9)'
      ELSE 'No Revenue'
    END AS clv_segment
  FROM user_clv
)
SELECT 
  clv_segment,
  platform,
  COUNT(*) AS user_count,
  ROUND(AVG(lifetime_days), 1) AS avg_lifetime_days,
  ROUND(AVG(total_transactions), 1) AS avg_transactions,
  ROUND(AVG(total_revenue), 2) AS avg_revenue,
  ROUND(SUM(total_revenue), 2) AS segment_total_revenue,
  ROUND(AVG(total_revenue / NULLIF(lifetime_days, 0)), 3) AS avg_daily_revenue
FROM clv_segments
WHERE platform IS NOT NULL
GROUP BY clv_segment, platform
ORDER BY 
  CASE clv_segment 
    WHEN 'High Value (100+)' THEN 1
    WHEN 'Medium Value (50-99)' THEN 2
    WHEN 'Low Value (10-49)' THEN 3
    WHEN 'Minimal Value (0-9)' THEN 4
    WHEN 'No Revenue' THEN 5
  END,
  platform;

-- Operating System Performance
WITH os_performance AS (
  SELECT 
    ui.os,
    COUNT(DISTINCT ui.user_id) AS total_users,
    COUNT(DISTINCT e.user_id) AS active_users,
    COUNT(e.id) AS total_events,
    SUM(e.fee) AS total_revenue,
    AVG(TIMESTAMP_DIFF(COALESCE(ui.last_login, DATE('2023-04-01')), ui.created_date, DAY)) AS avg_retention_days
  FROM user_info ui
  LEFT JOIN events e ON ui.user_id = e.user_id
  WHERE ui.os IS NOT NULL
  GROUP BY ui.os
)
SELECT 
  os,
  total_users,
  active_users,
  ROUND(active_users * 100.0 / total_users, 2) AS activation_rate,
  ROUND(total_revenue, 2) AS total_revenue,
  ROUND(total_revenue / NULLIF(active_users, 0), 2) AS revenue_per_active_user,
  ROUND(total_events / NULLIF(active_users, 0), 2) AS events_per_active_user,
  ROUND(avg_retention_days, 1) AS avg_retention_days
FROM os_performance
WHERE total_users >= 10
ORDER BY total_revenue DESC;

-- Peak Usage Hours Analysis
WITH hourly_usage AS (
  SELECT 
    EXTRACT(HOUR FROM datetime) AS hour_of_day,
    COUNT(DISTINCT user_id) AS unique_users,
    COUNT(*) AS total_events,
    SUM(fee) AS hourly_revenue,
    SUM(volume) AS hourly_volume
  FROM events
  GROUP BY EXTRACT(HOUR FROM datetime)
)
SELECT 
  hour_of_day,
  unique_users,
  total_events,
  ROUND(hourly_revenue, 2) AS hourly_revenue,
  ROUND(hourly_volume, 0) AS hourly_volume,
  ROUND(total_events / NULLIF(unique_users, 0), 2) AS events_per_user_per_hour,
  RANK() OVER (ORDER BY total_events DESC) AS usage_rank
FROM hourly_usage
ORDER BY hour_of_day;

-- Monthly Cohort Revenue Analysis
WITH monthly_cohorts AS (
  SELECT 
    DATE_TRUNC(ui.created_date, MONTH) AS cohort_month,
    ui.user_id,
    COALESCE(SUM(e.fee), 0) AS user_revenue,
    COUNT(e.id) AS user_events
  FROM user_info ui
  LEFT JOIN events e ON ui.user_id = e.user_id
  WHERE ui.created_date IS NOT NULL
  GROUP BY DATE_TRUNC(ui.created_date, MONTH), ui.user_id
)
SELECT 
  cohort_month,
  COUNT(*) AS cohort_size,
  COUNT(CASE WHEN user_revenue > 0 THEN 1 END) AS paying_users,
  ROUND(COUNT(CASE WHEN user_revenue > 0 THEN 1 END) * 100.0 / COUNT(*), 2) AS conversion_rate,
  ROUND(SUM(user_revenue), 2) AS cohort_total_revenue,
  ROUND(AVG(user_revenue), 2) AS avg_revenue_per_user,
  ROUND(SUM(user_revenue) / NULLIF(COUNT(CASE WHEN user_revenue > 0 THEN 1 END), 0), 2) AS avg_revenue_per_paying_user,
  ROUND(AVG(user_events), 1) AS avg_events_per_user
FROM monthly_cohorts
GROUP BY cohort_month
ORDER BY cohort_month;