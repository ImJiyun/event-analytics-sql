# DAU
SELECT
  event_date,
  COUNT(DISTINCT user_pseudo_id) AS dau,
  COUNT(DISTINCT CASE WHEN platform = 'Android' THEN user_pseudo_id END) AS dau_android,
  COUNT(DISTINCT CASE WHEN platform = 'iOS' THEN user_pseudo_id END) AS dau_ios
FROM
  `advanced.app_logs`
GROUP BY 
  event_date;

# WAU
WITH base AS (
  SELECT
    *,
    DATE_TRUNC(event_date, WEEK(MONDAY)) AS event_week
  FROM
    advanced.app_logs
)

SELECT
  event_week,
  COUNT(DISTINCT user_pseudo_id) AS wau,
  COUNT(DISTINCT CASE WHEN platform = 'Android' THEN user_pseudo_id END) AS wau_android,
  COUNT(DISTINCT CASE WHEN platform = 'iOS' THEN user_pseudo_id END) AS wau_ios
FROM
  base
GROUP BY
  event_week;

# MAU
WITH base AS (
  SELECT
    *,
    DATE_TRUNC(event_date, MONTH) AS event_month
  FROM
    advanced.app_logs
)

SELECT
  event_month,
  COUNT(DISTINCT user_pseudo_id) AS mau,
  COUNT(DISTINCT CASE WHEN platform = 'Android' THEN user_pseudo_id END) AS mau_android,
  COUNT(DISTINCT CASE WHEN platform = 'iOS' THEN user_pseudo_id END) AS mau_ios
FROM
  base
GROUP BY
  event_month;

# Stickiness Ratio (DAU / MAU)
WITH daily_users AS (
  SELECT
    event_date,
    COUNT(DISTINCT user_pseudo_id) AS dau
  FROM
    `advanced.app_logs`
  GROUP BY 
    event_date
), monthly_users AS (
  SELECT
    DATE_TRUNC(event_date, MONTH) AS month,
    COUNT(DISTINCT user_pseudo_id) AS mau
  FROM
    `advanced.app_logs`
  GROUP BY
    month
)

SELECT
  d.event_date,
  d.dau,
  m.mau,
  ROUND(d.dau / m.mau, 2) AS stickiness_ratio,
  CASE 
    WHEN d.dau / m.mau >= 0.2 THEN '우수'
    WHEN d.dau / m.mau >= 0.1 THEN '양호'
    ELSE '개선필요'
  END AS grade
FROM
  daily_users AS d
JOIN
  monthly_users AS m
ON
  DATE_TRUNC(d.event_date, MONTH) = m.month
ORDER BY
  d.event_date DESC;

# 요일별 사용자 분포
WITH base AS (
  SELECT
    *,
    EXTRACT(DAYOFWEEK FROM event_date) AS day_of_week
  FROM
    advanced.app_logs
)

SELECT
  CASE 
    WHEN day_of_week = 1 THEN '일요일'
    WHEN day_of_week = 2 THEN '월요일'
    WHEN day_of_week = 3 THEN '화요일'
    WHEN day_of_week = 4 THEN '수요일'
    WHEN day_of_week = 5 THEN '목요일'
    WHEN day_of_week = 6 THEN '금요일'
    ELSE '토요일'
  END AS day,
  COUNT(DISTINCT user_pseudo_id) AS dau,
  COUNT(*) AS total_events,
  ROUND(COUNT(*) / COUNT(DISTINCT user_pseudo_id), 2) AS events_per_user,

  COUNT(DISTINCT CASE WHEN event_name = 'click_food' THEN user_pseudo_id END) AS users_clicked_food,
  COUNT(DISTINCT CASE WHEN event_name = 'click_cart' THEN user_pseudo_id END) AS users_clicked_cart,
  COUNT(DISTINCT CASE WHEN event_name = 'click_payment' THEN user_pseudo_id END) AS users_clicked_payment
FROM
  base
GROUP BY  
  day_of_week;

# 신규 vs 재방문 사용자 
WITH first_visited AS (
  SELECT
    user_pseudo_id,
    MIN(event_date) AS first_date
  FROM
    advanced.app_logs
  GROUP BY
    user_pseudo_id
)

SELECT
  a.event_date,
  COUNT(DISTINCT a.user_pseudo_id) AS dau,
  COUNT(DISTINCT CASE WHEN a.event_date = f.first_date THEN a.user_pseudo_id END) AS new_users,
  COUNT(DISTINCT CASE WHEN a.event_date > f.first_date THEN a.user_pseudo_id END) AS revisited_users,

  ROUND(COUNT(DISTINCT CASE WHEN a.event_date = f.first_date THEN a.user_pseudo_id END) 
    / COUNT(DISTINCT a.user_pseudo_id), 2) AS new_user_ratio
FROM
  advanced.app_logs AS a
LEFT JOIN
   first_visited AS f
ON
  a.user_pseudo_id = f.user_pseudo_id
GROUP BY
  a.event_date
ORDER BY
  a.event_date DESC;

# 시간대별 사용자 활동
SELECT
  EXTRACT(HOUR FROM TIMESTAMP_MICROS(event_timestamp)) AS hour,
  COUNT(*) AS total_events,
  COUNT(DISTINCT user_pseudo_id) AS unique_users,  
  ROUND(100 * COUNT(*) / SUM(COUNT(*)) OVER(), 2) AS pct_of_total_events,
  ROUND(COUNT(*) / COUNT(DISTINCT user_pseudo_id), 2) AS events_per_user
FROM
  advanced.app_logs
GROUP BY
  hour
ORDER BY 
  hour

# 이벤트 빈도 분석
SELECT
  event_name,
  COUNT(*) AS total_events,
  COUNT(DISTINCT user_pseudo_id) AS unique_users,
  ROUND(COUNT(*) / COUNT(DISTINCT user_pseudo_id), 2) AS avg_per_user,
  ROUND(100.0 * COUNT(*) / SUM(COUNT(*)) OVER(), 2) AS pct_of_all_events
FROM
  advanced.app_logs
GROUP BY  
  event_name