-- Create platform usage summary table
CREATE TABLE platform_use AS (
  SELECT 
    date,
    COALESCE(web, 0) AS web,
    COALESCE(android, 0) AS android,
    COALESCE(ios, 0) AS ios
  FROM (
    SELECT 
      COALESCE(COUNT(*), 0) AS number_customers,
      e.platform,
      e.date
    FROM events AS e
    GROUP BY platform, date
  ) A
  PIVOT (
    SUM(number_customers)
    FOR platform IN ('web' AS web, 'android' AS android, 'ios' AS ios)
  ) AS pivot_table
);

-- Create volume usage over time table
CREATE TABLE volume_use AS (
  SELECT 
    SUM(volume) AS volume,
    date
  FROM events
  GROUP BY date
  ORDER BY date
);

-- Platform usage comparison query
SELECT 
  platform,
  COUNT(DISTINCT user_id) AS unique_users,
  COUNT(*) AS total_sessions,
  SUM(volume) AS total_volume,
  SUM(fee) AS total_revenue,
  AVG(volume) AS avg_volume_per_session,
  AVG(fee) AS avg_fee_per_session
FROM events
WHERE user_id IS NOT NULL
GROUP BY platform
ORDER BY total_revenue DESC;

-- Daily platform trends
SELECT 
  date,
  platform,
  COUNT(DISTINCT user_id) AS daily_active_users,
  SUM(volume) AS daily_volume,
  SUM(fee) AS daily_revenue
FROM events
GROUP BY date, platform
ORDER BY date, platform;

-- Platform performance metrics
WITH platform_stats AS (
  SELECT 
    platform,
    COUNT(DISTINCT user_id) AS users,
    AVG(volume) AS avg_volume,
    AVG(fee) AS avg_fee,
    COUNT(*) AS sessions
  FROM events
  GROUP BY platform
)
SELECT 
  platform,
  users,
  sessions,
  ROUND(sessions / users, 2) AS sessions_per_user,
  ROUND(avg_volume, 2) AS avg_volume,
  ROUND(avg_fee, 2) AS avg_fee,
  ROUND((users * 100.0) / SUM(users) OVER(), 2) AS user_percentage
FROM platform_stats
ORDER BY users DESC;