-- =====================================================
-- RFM Analysis & Customer Segmentation
-- Segments customers based on Recency, Frequency, Monetary
-- =====================================================

-- Step 1: Calculate RFM base metrics
CREATE TABLE rfm_base AS (
  SELECT 
    ui.user_id,
    ui.created_date,
    TIMESTAMP_DIFF(DATE('2023-04-01'), MAX(e.date), DAY) AS recency,
    COUNT(e.id) / TIMESTAMP_DIFF(DATE('2023-04-01'), ui.created_date, MONTH) AS frequency,
    SUM(fee) / TIMESTAMP_DIFF(DATE('2023-04-01'), ui.created_date, MONTH) AS monetary,
    ROW_NUMBER() OVER (ORDER BY TIMESTAMP_DIFF(DATE('2023-04-01'), MAX(e.date), DAY) DESC) AS recency_rn,
    ROW_NUMBER() OVER (ORDER BY COUNT(e.id) / TIMESTAMP_DIFF(DATE('2023-04-01'), ui.created_date, MONTH)) AS frequency_rn,
    ROW_NUMBER() OVER (ORDER BY SUM(fee) / TIMESTAMP_DIFF(DATE('2023-04-01'), ui.created_date, MONTH)) AS monetary_rn
  FROM events_updated e
  JOIN user_info ui ON e.user_id = ui.user_id
  WHERE ui.user_id IS NOT NULL
  GROUP BY ui.user_id, ui.created_date
);

-- Step 2: Calculate quartile-based RFM scores
CREATE TABLE rfm_scores AS (
  SELECT 
    *,
    CASE 
      WHEN recency < (SELECT recency FROM rfm_base WHERE recency_rn = CAST(0.25 * (SELECT COUNT(user_id) FROM rfm_base) AS INT64)) THEN 1
      WHEN recency >= (SELECT recency FROM rfm_base WHERE recency_rn = CAST(0.25 * (SELECT COUNT(user_id) FROM rfm_base) AS INT64))
        AND recency < (SELECT recency FROM rfm_base WHERE recency_rn = CAST(0.5 * (SELECT COUNT(user_id) FROM rfm_base) AS INT64)) THEN 2
      WHEN recency >= (SELECT recency FROM rfm_base WHERE recency_rn = CAST(0.5 * (SELECT COUNT(user_id) FROM rfm_base) AS INT64))
        AND recency < (SELECT recency FROM rfm_base WHERE recency_rn = CAST(0.75 * (SELECT COUNT(user_id) FROM rfm_base) AS INT64)) THEN 3
      ELSE 4 
    END AS R,
    
    CASE
      WHEN frequency < (SELECT frequency FROM rfm_base WHERE frequency_rn = CAST(0.25 * (SELECT COUNT(user_id) FROM rfm_base) AS INT64)) THEN 1
      WHEN frequency >= (SELECT frequency FROM rfm_base WHERE frequency_rn = CAST(0.25 * (SELECT COUNT(user_id) FROM rfm_base) AS INT64))
        AND frequency < (SELECT frequency FROM rfm_base WHERE frequency_rn = CAST(0.5 * (SELECT COUNT(user_id) FROM rfm_base) AS INT64)) THEN 2
      WHEN frequency >= (SELECT frequency FROM rfm_base WHERE frequency_rn = CAST(0.5 * (SELECT COUNT(user_id) FROM rfm_base) AS INT64))
        AND frequency < (SELECT frequency FROM rfm_base WHERE frequency_rn = CAST(0.75 * (SELECT COUNT(user_id) FROM rfm_base) AS INT64)) THEN 3
      ELSE 4 
    END AS F,
    
    CASE 
      WHEN monetary < (SELECT monetary FROM rfm_base WHERE monetary_rn = CAST(0.25 * (SELECT COUNT(user_id) FROM rfm_base) AS INT64)) THEN 1
      WHEN monetary >= (SELECT monetary FROM rfm_base WHERE monetary_rn = CAST(0.25 * (SELECT COUNT(user_id) FROM rfm_base) AS INT64))
        AND monetary < (SELECT monetary FROM rfm_base WHERE monetary_rn = CAST(0.5 * (SELECT COUNT(user_id) FROM rfm_base) AS INT64)) THEN 2
      WHEN monetary >= (SELECT monetary FROM rfm_base WHERE monetary_rn = CAST(0.5 * (SELECT COUNT(user_id) FROM rfm_base) AS INT64))
        AND monetary < (SELECT monetary FROM rfm_base WHERE monetary_rn = CAST(0.75 * (SELECT COUNT(user_id) FROM rfm_base) AS INT64)) THEN 3
      ELSE 4 
    END AS M
  FROM rfm_base
);

-- Step 3: Create RFM segments with business labels
CREATE TABLE rfm_segments AS (
  SELECT 
    user_id,
    created_date,
    recency,
    frequency,
    monetary,
    R,
    F,
    M,
    CONCAT(CAST(R AS STRING), CAST(F AS STRING), CAST(M AS STRING)) AS rfm_score,
    CASE 
      WHEN (R IN (1, 2)) AND (F IN (1, 2)) AND (M IN (1, 2)) THEN 'Walk-in Guests'
      WHEN (R IN (3, 4)) AND (F IN (1, 2)) AND (M IN (1, 2)) THEN 'Walk-in Guests'
      WHEN (R IN (1, 2)) AND (F IN (1, 2)) AND (M IN (3, 4)) THEN 'Potential Customers'
      WHEN (R IN (3, 4)) AND (F IN (1, 2)) AND (M IN (3, 4)) THEN 'Potential Customers'
      WHEN (R IN (3, 4)) AND (F IN (3, 4)) AND (M IN (1, 2)) THEN 'Regular Customers'
      WHEN (R IN (3, 4)) AND (F IN (3, 4)) AND (M IN (3, 4)) THEN 'VIP'
      WHEN (R IN (1, 2)) AND (F IN (3, 4)) THEN 'At-risk Customer'
      ELSE 'Other'
    END AS customer_segment
  FROM rfm_scores
);

-- Customer segment analysis
SELECT 
  customer_segment,
  COUNT(*) AS customer_count,
  ROUND(COUNT(*) * 100.0 / SUM(COUNT(*)) OVER(), 2) AS percentage,
  ROUND(AVG(recency), 2) AS avg_recency,
  ROUND(AVG(frequency), 2) AS avg_frequency,
  ROUND(AVG(monetary), 2) AS avg_monetary,
  ROUND(SUM(monetary), 2) AS total_revenue_contribution
FROM rfm_segments
GROUP BY customer_segment
ORDER BY customer_count DESC;

-- RFM score distribution
SELECT 
  rfm_score,
  customer_segment,
  COUNT(*) AS count,
  ROUND(COUNT(*) * 100.0 / SUM(COUNT(*)) OVER(), 2) AS percentage
FROM rfm_segments
GROUP BY rfm_score, customer_segment
ORDER BY count DESC
LIMIT 20;

-- Geographic RFM analysis
SELECT 
  g.country,
  rs.customer_segment,
  COUNT(*) AS customer_count,
  ROUND(AVG(rs.monetary), 2) AS avg_monetary_value,
  ROUND(SUM(rs.monetary), 2) AS total_revenue
FROM rfm_segments rs
JOIN user_info ui ON rs.user_id = ui.user_id
JOIN geography g ON ui.mp_country_code = g.code
GROUP BY g.country, rs.customer_segment
HAVING COUNT(*) >= 10
ORDER BY g.country, total_revenue DESC;

-- Platform-specific RFM insights
SELECT 
  ui.platform,
  rs.customer_segment,
  COUNT(*) AS customer_count,
  ROUND(AVG(rs.frequency), 2) AS avg_frequency,
  ROUND(AVG(rs.monetary), 2) AS avg_monetary
FROM rfm_segments rs
JOIN user_info ui ON rs.user_id = ui.user_id
WHERE ui.platform IS NOT NULL
GROUP BY ui.platform, rs.customer_segment
ORDER BY ui.platform, customer_count DESC;

-- Customer lifecycle analysis
WITH lifecycle_metrics AS (
  SELECT 
    customer_segment,
    COUNT(*) AS total_customers,
    AVG(TIMESTAMP_DIFF(DATE('2023-04-01'), created_date, DAY)) AS avg_customer_age_days,
    AVG(recency) AS avg_days_since_last_use,
    AVG(frequency) AS avg_monthly_frequency,
    AVG(monetary) AS avg_monthly_revenue
  FROM rfm_segments
  GROUP BY customer_segment
)
SELECT 
  customer_segment,
  total_customers,
  ROUND(avg_customer_age_days, 1) AS avg_customer_age_days,
  ROUND(avg_days_since_last_use, 1) AS avg_days_since_last_use,
  ROUND(avg_monthly_frequency, 2) AS avg_monthly_frequency,
  ROUND(avg_monthly_revenue, 2) AS avg_monthly_revenue,
  ROUND(avg_monthly_revenue * avg_monthly_frequency, 2) AS estimated_monthly_clv
FROM lifecycle_metrics
ORDER BY estimated_monthly_clv DESC;

-- Segment transition opportunities
SELECT 
  'VIP' AS target_segment,
  COUNT(CASE WHEN customer_segment = 'Regular Customers' THEN 1 END) AS from_regular,
  COUNT(CASE WHEN customer_segment = 'Potential Customers' THEN 1 END) AS from_potential,
  COUNT(CASE WHEN customer_segment = 'At-risk Customer' THEN 1 END) AS from_at_risk
FROM rfm_segments

UNION ALL

SELECT 
  'Regular Customers' AS target_segment,
  COUNT(CASE WHEN customer_segment = 'Potential Customers' THEN 1 END) AS from_potential,
  COUNT(CASE WHEN customer_segment = 'Walk-in Guests' THEN 1 END) AS from_walk_in,
  COUNT(CASE WHEN customer_segment = 'At-risk Customer' THEN 1 END) AS from_at_risk
FROM rfm_segments;