-- =====================================================
-- Event Recalculation with 6-Hour Intervals
-- Prevents gaming by grouping frequent access into sessions
-- =====================================================

-- Create updated events table with 6-hour interval grouping
CREATE TABLE events_updated AS (
  WITH new_events AS (
    WITH access_group AS (
      SELECT 
        *,
        CASE 
          WHEN datetime < TIMESTAMP_ADD(min_time, INTERVAL 360 MINUTE) THEN 1
          WHEN datetime BETWEEN TIMESTAMP_ADD(min_time, INTERVAL 360 MINUTE) 
               AND TIMESTAMP_ADD(min_time, INTERVAL 720 MINUTE) THEN 2
          WHEN datetime BETWEEN TIMESTAMP_ADD(min_time, INTERVAL 720 MINUTE) 
               AND TIMESTAMP_ADD(min_time, INTERVAL 1080 MINUTE) THEN 3
          ELSE 4 
        END AS grp
      FROM (
        SELECT 
          *,
          MIN(datetime) OVER (
            PARTITION BY user_id, platform, date
            ORDER BY datetime
          ) AS min_time
        FROM events
        WHERE user_id IS NOT NULL
      )
    )
    
    SELECT
      user_id,
      DATE(datetime) AS date,
      MIN(datetime) AS datetime,
      platform,
      SUM(volume) AS volume,
      SUM(fee) AS fee,
      grp
    FROM access_group
    GROUP BY user_id, date, platform, grp
  )
  
  SELECT
    ROW_NUMBER() OVER (ORDER BY user_id, new_events.date, grp) AS id,
    user_id,
    date,
    datetime,
    platform,
    volume,
    fee
  FROM new_events
);

-- Analysis: Compare original vs updated event counts
WITH original_stats AS (
  SELECT 
    user_id,
    platform,
    DATE(datetime) AS date,
    COUNT(*) AS original_events,
    SUM(volume) AS original_volume,
    SUM(fee) AS original_fee
  FROM events
  WHERE user_id IS NOT NULL
  GROUP BY user_id, platform, DATE(datetime)
),

updated_stats AS (
  SELECT 
    user_id,
    platform,
    date,
    COUNT(*) AS updated_events,
    SUM(volume) AS updated_volume,
    SUM(fee) AS updated_fee
  FROM events_updated
  GROUP BY user_id, platform, date
)

SELECT 
  o.user_id,
  o.platform,
  o.date,
  o.original_events,
  u.updated_events,
  o.original_events - u.updated_events AS events_reduced,
  ROUND((o.original_events - u.updated_events) * 100.0 / o.original_events, 2) AS reduction_percentage,
  o.original_volume,
  u.updated_volume,
  o.original_fee,
  u.updated_fee
FROM original_stats o
JOIN updated_stats u 
  ON o.user_id = u.user_id 
  AND o.platform = u.platform 
  AND o.date = u.date
WHERE o.original_events > u.updated_events
ORDER BY events_reduced DESC
LIMIT 20;

-- Impact analysis on frequent users
WITH user_impact AS (
  SELECT 
    o.user_id,
    SUM(o.original_events) AS total_original_events,
    SUM(u.updated_events) AS total_updated_events,
    SUM(o.original_events - u.updated_events) AS total_events_reduced,
    ROUND(AVG((o.original_events - u.updated_events) * 100.0 / o.original_events), 2) AS avg_reduction_pct
  FROM original_stats o
  JOIN updated_stats u 
    ON o.user_id = u.user_id 
    AND o.platform = u.platform 
    AND o.date = u.date
  GROUP BY o.user_id
  HAVING SUM(o.original_events) >= 10  -- Focus on active users
)

SELECT 
  CASE 
    WHEN total_original_events >= 100 THEN 'Heavy Users (100+ events)'
    WHEN total_original_events >= 50 THEN 'Moderate Users (50-99 events)'
    WHEN total_original_events >= 20 THEN 'Regular Users (20-49 events)'
    ELSE 'Light Users (10-19 events)'
  END AS user_category,
  COUNT(*) AS user_count,
  ROUND(AVG(total_original_events), 1) AS avg_original_events,
  ROUND(AVG(total_updated_events), 1) AS avg_updated_events,
  ROUND(AVG(total_events_reduced), 1) AS avg_events_reduced,
  ROUND(AVG(avg_reduction_pct), 2) AS avg_reduction_percentage
FROM user_impact
GROUP BY 
  CASE 
    WHEN total_original_events >= 100 THEN 'Heavy Users (100+ events)'
    WHEN total_original_events >= 50 THEN 'Moderate Users (50-99 events)'
    WHEN total_original_events >= 20 THEN 'Regular Users (20-49 events)'
    ELSE 'Light Users (10-19 events)'
  END
ORDER BY avg_original_events DESC;

-- Platform-specific impact analysis
SELECT 
  platform,
  COUNT(DISTINCT user_id) AS affected_users,
  SUM(original_events) AS total_original_events,
  SUM(updated_events) AS total_updated_events,
  SUM(original_events - updated_events) AS total_events_reduced,
  ROUND((SUM(original_events - updated_events) * 100.0 / SUM(original_events)), 2) AS platform_reduction_pct
FROM (
  SELECT 
    o.user_id,
    o.platform,
    SUM(o.original_events) AS original_events,
    SUM(u.updated_events) AS updated_events
  FROM original_stats o
  JOIN updated_stats u 
    ON o.user_id = u.user_id 
    AND o.platform = u.platform 
    AND o.date = u.date
  GROUP BY o.user_id, o.platform
  HAVING SUM(o.original_events) > SUM(u.updated_events)
)
GROUP BY platform
ORDER BY platform_reduction_pct DESC;

-- Time-based impact analysis
WITH daily_impact AS (
  SELECT 
    o.date,
    SUM(o.original_events) AS daily_original_events,
    SUM(u.updated_events) AS daily_updated_events,
    SUM(o.original_events - u.updated_events) AS daily_events_reduced
  FROM original_stats o
  JOIN updated_stats u 
    ON o.user_id = u.user_id 
    AND o.platform = u.platform 
    AND o.date = u.date
  GROUP BY o.date
)

SELECT 
  date,
  daily_original_events,
  daily_updated_events,
  daily_events_reduced,
  ROUND((daily_events_reduced * 100.0 / daily_original_events), 2) AS daily_reduction_pct
FROM daily_impact
WHERE daily_events_reduced > 0
ORDER BY daily_reduction_pct DESC
LIMIT 10;

-- Identify potential gaming patterns before recalculation
WITH gaming_patterns AS (
  SELECT 
    user_id,
    platform,
    DATE(datetime) AS date,
    COUNT(*) AS daily_events,
    COUNT(DISTINCT EXTRACT(HOUR FROM datetime)) AS unique_hours,
    MIN(datetime) AS first_access,
    MAX(datetime) AS last_access,
    TIMESTAMP_DIFF(MAX(datetime), MIN(datetime), MINUTE) AS session_duration_minutes
  FROM events
  WHERE user_id IS NOT NULL
  GROUP BY user_id, platform, DATE(datetime)
  HAVING COUNT(*) >= 10  -- Focus on high-frequency days
)

SELECT 
  user_id,
  platform,
  date,
  daily_events,
  unique_hours,
  session_duration_minutes,
  ROUND(daily_events / unique_hours, 2) AS events_per_hour,
  CASE 
    WHEN daily_events > 50 AND session_duration_minutes < 60 THEN 'Likely Gaming'
    WHEN daily_events > 30 AND unique_hours <= 2 THEN 'Possible Gaming'
    WHEN daily_events > 20 AND session_duration_minutes < 30 THEN 'Suspicious Pattern'
    ELSE 'Normal Usage'
  END AS gaming_assessment
FROM gaming_patterns
WHERE daily_events >= 15
ORDER BY daily_events DESC, session_duration_minutes ASC
LIMIT 50;