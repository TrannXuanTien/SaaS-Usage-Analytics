# SaaS User Analytics Project
## Comprehensive User Behavior Analysis & Customer Segmentation

**Author:** Tran Xuan Tien  
**Platform:** Google BigQuery  

---

##  Project Overview

This project provides a comprehensive analysis of user behavior, retention patterns, and customer segmentation for a Software as a Service (SaaS) platform. Using advanced SQL analytics and RFM (Recency, Frequency, Monetary) modeling, the project delivers actionable insights for improving user retention, identifying fraud patterns, and optimizing customer lifetime value.

### Key Business Objectives
- **User Retention Analysis**: Track 7-day, 14-day, and 28-day retention rates
- **Fraud Detection**: Identify users exploiting trial periods through repeated account creation
- **Customer Segmentation**: RFM-based segmentation for targeted marketing strategies
- **Platform Performance**: Cross-platform usage analysis (Web, Android, iOS)
- **Geographic Analysis**: User distribution and behavior patterns by country

---

## Key Findings & Business Impact

### Critical Insights
- **Retention Crisis**: 2023 users showed 2-5% retention vs 100% for 2022 users
- **Geographic Risk**: Indonesia and Pakistan account for 492 and 339 serious cheaters respectively
- **Platform Dominance**: Android users represent majority, iOS represents untapped opportunity
- **Customer Health**: 98.5% of users are either At-Risk (48.5%) or Potential (50%) customers
- **Usage Patterns**: Peak usage occurs on 25th-28th of each month (200K+ units)

### Financial Impact
- **Fraud Loss**: Identified systematic trial abuse across multiple regions
- **Revenue Opportunity**: 70% of customer base generates minimal revenue
- **Retention Risk**: Nearly half of customer base classified as "At-Risk"

---

##  Technical Architecture

### Data Sources
| Table | Description | Key Fields |
|-------|-------------|------------|
| **user_info** | User profiles and account status | user_id, platform, country_code, created_date, last_login |
| **events** | User interaction logs (Jan-Feb 2023) | user_id, datetime, platform, volume, fee |
| **geography** | Geographic reference data | country_code, country, latitude, longitude |

### Technology Stack
- **Database**: Google BigQuery
- **Language**: SQL (BigQuery Standard SQL)
- **Analytics**: RFM Analysis, Cohort Analysis, Fraud Detection
- **Visualization**: Charts and reports for business stakeholders

---

## Analytics Modules

### 1. Platform Usage Analysis
```sql
-- Track daily usage across platforms (Web, Android, iOS)
create table finaltest.platform_use as(
  select date,
    coalesce(web,0) as web,
    coalesce(android,0) as android,
    coalesce(ios,0) as IOS
  from (
    select coalesce(count(*),0) as number_customers, e.platform, e.date
    from finaltest.events as e
    group by platform, date
  ) A
  PIVOT (sum(number_customers)
    FOR platform IN ('web' AS web, 'android' AS android, 'ios' AS ios)
  ) as Pivot_table
);
```

### 2. User Retention Analysis
- **7-Day Intervals**: Track user retention across 7 weekly periods (49 days total)
- **Cohort-Based**: Analyze retention by registration date
- **Trend Analysis**: Compare 2022 vs 2023 retention patterns

### 3. Fraud Detection Algorithm
```sql
-- Identify users with >5 trial abuse instances
with suspended_in_trial as (
  select * from (
    select id, user_id, mp_country_code, created_date,
           coalesce(last_login, DATE('2023-04-01')) as last_login, os
    from `finaltest.user_info`
  ) a
  where IFNULL(TIMESTAMP_DIFF(last_login, created_date, DAY),
               TIMESTAMP_DIFF(PARSE_DATE('%Y-%m-%d', '2023-03-01'), created_date, DAY)) <= 3
)
```

### 4. RFM Customer Segmentation
- **Recency**: Days since last platform usage
- **Frequency**: Average usage frequency during subscription period
- **Monetary**: Average revenue contribution per subscription period
- **Quartile-Based Scoring**: 1-4 scale for each RFM dimension

### 5. Advanced Event Calculation
**6-Hour Interval Grouping**: Consolidates frequent access attempts into meaningful usage sessions to prevent gaming of usage metrics.

---

##  Customer Segmentation Framework

### RFM-Based Segments
| Segment | Characteristics | Population | Strategy |
|---------|----------------|------------|----------|
| **VIP Customers** | High R,F,M scores | 1.5% | Retention & expansion |
| **At-Risk Customers** | Low recency, any F,M | 48.5% | Win-back campaigns |
| **Potential Customers** | Mixed scores, growth potential | 50% | Upgrade & engagement |
| **Walk-in Guests** | Low engagement across all metrics | Minimal | Basic onboarding |

### Business Strategy Matrix
Using BCG Matrix adaptation:
- **Stars**: High frequency + High recency → VIP Customers
- **Cash Cows**: High frequency + Low recency → At-Risk Customers  
- **Question Marks**: Low frequency + High recency → Potential Customers
- **Dogs**: Low frequency + Low recency → Walk-in Guests

---

##  Fraud Prevention System

### Detection Criteria
1. **Trial Abuse**: Account suspension within 3 days of registration
2. **Pattern Recognition**: Same user_id, country_code, and OS combination
3. **Threshold**: >5 instances flagged as "serious cheater"
4. **Geographic Clustering**: Country-level fraud risk assessment

### High-Risk Regions
| Country | Serious Cheaters | Risk Level |
|---------|------------------|------------|
| Indonesia | 492 | Critical |
| Pakistan | 339 | High |
| India | ~200 | Medium-High |
| Philippines | ~200 | Medium-High |
| Bangladesh | ~200 | Medium-High |

---

---

## Getting Started

### Setup Instructions

1. **Clone the repository**
```bash
git clone https://github.com/yourusername/saas-user-analytics.git
cd saas-user-analytics
```

2. **Configure BigQuery**
```sql
-- Set your project ID
SET @@project_id = 'your-project-id';

-- Create dataset
CREATE SCHEMA IF NOT EXISTS finaltest;
```

3. **Load sample data** (if using your own dataset)
```sql
-- Update table references in SQL files
-- Replace 'finaltest' with your dataset name
```

4. **Run analysis modules**
```bash
# Execute SQL files in order:
# 1. Platform analysis
# 2. Retention analysis  
# 3. Fraud detection
# 4. RFM segmentation
```

---

## Key Metrics & KPIs

### User Engagement
- **Daily Active Users (DAU)**: Platform-specific tracking
- **Monthly Usage Volume**: 200K+ units peak periods
- **Session Frequency**: 6-hour interval grouping

### Retention Metrics
- **7-Day Retention**: Critical health indicator
- **Cohort Analysis**: Registration date-based tracking
- **Churn Prediction**: At-risk customer identification

### Revenue Metrics
- **Customer Lifetime Value (CLV)**: RFM-based calculation
- **Revenue Distribution**: 70% from low-value customers
- **Upgrade Potential**: Potential customer segment analysis

### Fraud Metrics
- **Trial Abuse Rate**: Country and platform-specific
- **Serious Cheater Count**: >5 instance threshold
- **Risk Assessment**: Geographic fraud mapping

---

##  Advanced Analytics Features

### 1. Geographic Analysis
- User distribution across top 10 countries
- Fraud risk assessment by region
- Cultural behavior pattern analysis

### 2. Platform Optimization
- Cross-platform usage comparison
- iOS opportunity identification
- Android user preference analysis

### 3. Temporal Patterns
- Monthly usage cycles (peak: 25th-28th)
- Seasonal behavior trends
- Time-based retention analysis

### 4. Predictive Elements
- Churn risk scoring
- Upgrade probability modeling
- Fraud detection automation

---

##  Business Recommendations

### Immediate Actions (0-30 days)
1. **Fraud Mitigation**: Implement stricter trial controls for high-risk regions
2. **iOS Strategy**: Develop iOS-specific features and marketing
3. **At-Risk Recovery**: Launch targeted win-back campaigns

### Strategic Initiatives (30-90 days)
1. **Customer Success Program**: Focus on Potential → VIP conversion
2. **Regional Policies**: Customized approaches for different markets
3. **Product Enhancement**: Address retention issues identified in 2023 data

### Long-term Vision (90+ days)
1. **Predictive Analytics**: Real-time churn and fraud prediction
2. **Personalization Engine**: RFM-based feature recommendations
3. **Global Expansion**: Strategic entry into low-risk, high-potential markets

---
## Additional Resources

- [RFM Analysis Best Practices](https://blog.google/products/analytics/)
- [Customer Segmentation Strategies](https://www.salesforce.com/resources/articles/customer-segmentation/)
- [Fraud Detection in SaaS](https://stripe.com/guides/fraud-prevention)

---

**Note**: This project contains analytical insights based on real user behavior patterns. Ensure compliance with data privacy regulations (GDPR, CCPA) when implementing similar analyses in production environments.

**Last Updated**: June 2025  
**Version**: 2.0  
