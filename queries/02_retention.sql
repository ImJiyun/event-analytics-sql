# Day 1 리텐션
# D1 Retention이 1-2% 수준으로 낮음
WITH first_visited AS (
  SELECT
    user_pseudo_id,
    MIN(DATE(event_date)) AS first_date
  FROM
    advanced.app_logs
  GROUP BY
    user_pseudo_id
), user_activity AS (
  SELECT 
    DISTINCT
      user_pseudo_id,
      DATE(event_date) AS activity_date
  FROM
    advanced.app_logs
), d1_retention AS (
  SELECT
    f.first_date,
    COUNT(DISTINCT f.user_pseudo_id) AS users,
    COUNT(DISTINCT CASE WHEN u.activity_date = DATE_ADD(f.first_date, INTERVAL 1 DAY) THEN f.user_pseudo_id END) AS d1_retained_users
  FROM
    first_visited AS f
  LEFT JOIN
    user_activity AS u
  ON
    f.user_pseudo_id = u.user_pseudo_id
  GROUP BY
    f.first_date
)

SELECT
  *,
  ROUND(100 * d1_retained_users / users, 2) AS d1_retention_rate 
FROM
  d1_retention;

# Rolling 7 DAY Retention
# Rolling D7 Retention이 8-10% 수준으로 낮음
WITH first_visited AS (
  SELECT
    user_pseudo_id,
    MIN(DATE(event_date)) AS first_date
  FROM
    advanced.app_logs
  GROUP BY
    user_pseudo_id
), user_activity AS (
  SELECT 
    DISTINCT
      user_pseudo_id,
      DATE(event_date) AS activity_date
  FROM
    advanced.app_logs
), d1_d7_retention AS (
  SELECT
    f.first_date,
    COUNT(DISTINCT f.user_pseudo_id) AS users,
    COUNT(DISTINCT 
      CASE WHEN u.activity_date 
        BETWEEN DATE_ADD(f.first_date, INTERVAL 1 DAY) 
        AND DATE_ADD(f.first_date, INTERVAL 7 DAY)
        THEN f.user_pseudo_id END) AS d1_d7_retained_users
  FROM
    first_visited AS f
  LEFT JOIN
    user_activity AS u
  ON
    f.user_pseudo_id = u.user_pseudo_id
  GROUP BY 
    f.first_date
)

SELECT
  *,
  ROUND(100 * d1_d7_retained_users / users, 2) AS d1_d7_retention_ratio
FROM
  d1_d7_retention