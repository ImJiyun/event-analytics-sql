# 퍼널 분석 
# 단계별 전환율
  # step2 (login) -> step3 (food category) : 65%만 전환
  # step4 (restuarant) -> step5 (food) : 62%만 전환
  # step6 (cart) -> step7 (payment) : 66%만 전환
# 전체 전환율
  # step1 (screen view) -> step7 (payment) : 21%만 전환
WITH funnel AS (
  SELECT
    COUNT(DISTINCT CASE WHEN event_name = 'screen_view' THEN user_pseudo_id END) AS step1_view,
    COUNT(DISTINCT CASE WHEN event_name = 'click_login' THEN user_pseudo_id END) AS step2_login,
    COUNT(DISTINCT CASE WHEN event_name = 'click_food_category' THEN user_pseudo_id END) AS step3_category,
    COUNT(DISTINCT CASE WHEN event_name = 'click_restaurant' THEN user_pseudo_id END) AS step4_restaurant,
    COUNT(DISTINCT CASE WHEN event_name = 'click_food' THEN user_pseudo_id END) AS step5_food,
    COUNT(DISTINCT CASE WHEN event_name = 'click_cart' THEN user_pseudo_id END) AS step6_cart,
    COUNT(DISTINCT CASE WHEN event_name = 'click_payment' THEN user_pseudo_id END) AS step7_payment
  FROM advanced.app_logs
)

SELECT
  'Step 1: Screen View' AS step,
  step1_view AS users,
  100.0 AS conversion_from_prev,  
  100.0 AS conversion_from_start  
FROM funnel

UNION ALL

SELECT
  'Step 2: Login',
  step2_login,
  ROUND(100.0 * step2_login / step1_view, 2),
  ROUND(100.0 * step2_login / step1_view, 2)
FROM funnel

UNION ALL

SELECT
  'Step 3: Food Category',
  step3_category,
  ROUND(100.0 * step3_category / step2_login, 2),   
  ROUND(100.0 * step3_category / step1_view, 2)    
FROM funnel

UNION ALL

SELECT
  'Step 4: Restaurant',
  step4_restaurant,
  ROUND(100.0 * step4_restaurant / step3_category, 2),
  ROUND(100.0 * step4_restaurant / step1_view, 2)
FROM funnel

UNION ALL

SELECT
  'Step 5: Food',
  step5_food,
  ROUND(100.0 * step5_food / step4_restaurant, 2),
  ROUND(100.0 * step5_food / step1_view, 2)
FROM funnel

UNION ALL

SELECT
  'Step 6: Cart',
  step6_cart,
  ROUND(100.0 * step6_cart / step5_food, 2),
  ROUND(100.0 * step6_cart / step1_view, 2)
FROM funnel

UNION ALL

SELECT
  'Step 7: Payment',
  step7_payment,
  ROUND(100.0 * step7_payment / step6_cart, 2),
  ROUND(100.0 * step7_payment / step1_view, 2)
FROM funnel;

# 이탈 단계별 사용자 분류
WITH user_journey AS (
  SELECT
    user_pseudo_id,
      MAX(CASE WHEN event_name = 'screen_view' THEN 1 ELSE 0 END) AS reached_view,
      MAX(CASE WHEN event_name = 'click_login' THEN 1 ELSE 0 END) AS reached_login,
      MAX(CASE WHEN event_name = 'click_food_category' THEN 1 ELSE 0 END) AS reached_category,
      MAX(CASE WHEN event_name = 'click_restaurant' THEN 1 ELSE 0 END) AS reached_restaurant,
      MAX(CASE WHEN event_name = 'click_food' THEN 1 ELSE 0 END) AS reached_food,
      MAX(CASE WHEN event_name = 'click_cart' THEN 1 ELSE 0 END) AS reached_cart,
      MAX(CASE WHEN event_name = 'click_payment' THEN 1 ELSE 0 END) AS reached_payment
    FROM
    advanced.app_logs
  GROUP BY
    user_pseudo_id
)

SELECT
  CASE 
    WHEN reached_payment = 1 THEN '결제 완료'
    WHEN reached_cart = 1 THEN '장바구니에서 이탈'
    WHEN reached_food = 1 THEN '메뉴 선택에서 이탈'
    WHEN reached_restaurant = 1 THEN '음식점 선택에서 이탈'
    WHEN reached_category = 1 THEN '카테고리에서 이탈'
    WHEN reached_login = 1 THEN '로그인에서 이탈'
    ELSE '첫 화면에서 이탈'
  END AS dropoff_stage,
  COUNT(*) AS user_count,
  ROUND(100 * COUNT(*) / SUM(COUNT(*)) OVER(), 2) AS percentage
FROM
  user_journey 
GROUP BY 
  dropoff_stage
ORDER BY 
  user_count DESC;

# guest user 확인
# 총 사용자: 52,823명
# 게스트: 52,823명 (100%)
# 로그인: 49,678명 (94%)
SELECT
  COUNT(DISTINCT CASE WHEN user_id IS NULL THEN user_pseudo_id END) AS guest_users,
  COUNT(DISTINCT CASE WHEN user_id IS NOT NULL THEN user_pseudo_id END) AS logged_in_users,
  COUNT(DISTINCT user_pseudo_id) AS total_users
FROM
  advanced.app_logs;

# 로그인 시도 vs 성공
# 로그인 성공 : 94%
# 로그인 시도했으나 실패 : 0%
# 로그인 시도 안함 : 6%
WITH login_attempts AS (
  SELECT
    user_pseudo_id,
    MAX(CASE WHEN event_name = 'click_login' THEN 1 ELSE 0 END) AS attempted_login,
    MAX(CASE WHEN user_id IS NOT NULL THEN 1 ELSE 0 END) AS successful_login
  FROM
    advanced.app_logs
  GROUP BY
    user_pseudo_id  
)

SELECT
  CASE 
    WHEN attempted_login = 1 AND successful_login = 1 THEN '로그인 성공'
    WHEN attempted_login = 1 AND successful_login = 0 THEN '로그인 시도했으나 실패'
    ELSE '로그인 시도 안함'
  END AS login_status,
  COUNT(*) AS user_count,
  ROUND(100 * COUNT(*) / SUM(COUNT(*)) OVER (), 2) AS percentage
FROM
  login_attempts
GROUP BY
  login_status;

# 로그인 후 첫 행동
# 사용자별 첫 로그인 후 행동만 분석
WITH first_login AS (
  SELECT
    user_pseudo_id,
    MIN(event_timestamp) AS first_login_time
  FROM
    advanced.app_logs
  WHERE
    event_name = 'click_login'
  GROUP BY
    user_pseudo_id
),
first_login_events AS (
  SELECT
    a.user_pseudo_id,
    a.event_timestamp,
    a.event_name,
    LEAD(a.event_name) OVER (PARTITION BY a.user_pseudo_id ORDER BY a.event_timestamp) AS next_event
  FROM
    advanced.app_logs a
  INNER JOIN
    first_login f
  ON
    a.user_pseudo_id = f.user_pseudo_id
    AND a.event_timestamp = f.first_login_time
)

SELECT
  CASE 
    WHEN next_event IS NULL THEN '로그인 후 이탈'
    ELSE CONCAT('로그인 → ', next_event)
  END AS login_flow,
  COUNT(*) AS user_count,
  ROUND(100.0 * COUNT(*) / SUM(COUNT(*)) OVER (), 2) AS percentage
FROM
  first_login_events
GROUP BY
  login_flow
ORDER BY
  user_count DESC;

# 사용자당 로그인 횟수
WITH login_cnt_per_user AS (
  SELECT
    user_pseudo_id,
    COUNT(*) AS login_count
  FROM 
    advanced.app_logs
  WHERE
    event_name = 'click_login'
  GROUP BY
    user_pseudo_id
)

SELECT
  login_count,
  COUNT(*) AS user_count,
  ROUND(100 * COUNT(*) / SUM(COUNT(*)) OVER (), 2) AS percentage
FROM
  login_cnt_per_user
GROUP BY
  login_count
ORDER BY
  login_count;

# click_login 바로 다음 이벤트는 뭘까?
# click_login → screen_view: 105,106건 (100%) 
WITH all_events AS (
  SELECT
    user_pseudo_id,
    event_timestamp,
    event_name,
    LAG(event_name) OVER (PARTITION BY user_pseudo_id ORDER BY event_timestamp) AS prev_event
  FROM
    advanced.app_logs
)

SELECT
  prev_event,
  event_name AS next_event,
  COUNT(*) AS count,
  ROUND(100.0 * COUNT(*) / SUM(COUNT(*)) OVER (), 2) AS percentage
FROM
  all_events
WHERE
  prev_event = 'click_login'
GROUP BY
  prev_event, 
  event_name
ORDER BY
  count DESC
LIMIT 10;

# 로그인 후 screen_view에서 어떤 행동을 하는지 확인
WITH post_login AS (
  SELECT
    user_pseudo_id,
    event_timestamp,
    event_name,
    LAG(event_name) OVER (PARTITION BY user_pseudo_id ORDER BY event_timestamp) AS prev_event
  FROM
    advanced.app_logs
)

SELECT
  event_name AS action_after_screen_view,
  COUNT(*) AS count,
  ROUND(100.0 * COUNT(*) / SUM(COUNT(*)) OVER (), 2) AS percentage
FROM
  post_login
WHERE
  prev_event = 'screen_view'
  AND event_name != 'screen_view'
GROUP BY
  event_name
ORDER BY
  count DESC
LIMIT 10;
