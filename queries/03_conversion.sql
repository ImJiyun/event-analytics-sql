# 퍼널 분석 (수정된 버전)
# 주요 개선사항:
#   - Step 1: screen_view 전체 → welcome 화면만으로 좁힘
#   - Step 3: click_food_category 단일 경로 → 카테고리/검색/배너/근처 통합
#   - base CTE: event_params unnest 후 피벗하여 firebase_screen 등 파라미터 활용

WITH base AS (
  SELECT
    event_date,
    DATETIME(TIMESTAMP_MICROS(event_timestamp), "Asia/Seoul") AS event_datetime,
    event_name,
    user_pseudo_id,
    platform,
    MAX(IF(param.key = "firebase_screen", param.value.string_value, NULL)) AS firebase_screen,
    MAX(IF(param.key = "food_id", param.value.int_value, NULL)) AS food_id,
    MAX(IF(param.key = "session_id", param.value.string_value, NULL)) AS session_id,
    MAX(IF(param.key = "is_meet_min_order_price", param.value.int_value, NULL)) AS is_meet_min_order_price,
    MAX(IF(param.key = "banner_id", param.value.int_value, NULL)) AS banner_id,
    MAX(IF(param.key = "restaurant_id", param.value.int_value, NULL)) AS restaurant_id,
    MAX(IF(param.key = "food_category", param.value.string_value, NULL)) AS food_category,
    MAX(IF(param.key = "search_keyword", param.value.string_value, NULL)) AS search_keyword,
    MAX(IF(param.key = "payment_type", param.value.string_value, NULL)) AS payment_type,
    MAX(IF(param.key = "use_recommend_food", param.value.string_value, NULL)) AS use_recommend_food
  FROM advanced.app_logs
  CROSS JOIN UNNEST(event_params) AS param
  GROUP BY ALL
),

user_journey AS (
  SELECT
    user_pseudo_id,
    -- step1: welcome 화면을 본 것만 인정 (screen_view 전체가 아님)
    MAX(CASE WHEN event_name = 'screen_view' AND firebase_screen = 'welcome' THEN 1 ELSE 0 END) AS reached_welcome,
    MAX(CASE WHEN event_name = 'click_login' THEN 1 ELSE 0 END) AS reached_login,
    -- step3: 카테고리/검색/배너/근처 통합 (단일 경로 가정 제거)
    MAX(CASE WHEN event_name IN ('click_food_category', 'click_search', 'click_banner', 'click_restaurant_nearby')
        THEN 1 ELSE 0 END) AS reached_explore,
    MAX(CASE WHEN event_name = 'click_restaurant' THEN 1 ELSE 0 END) AS reached_restaurant,
    MAX(CASE WHEN event_name = 'click_cart' THEN 1 ELSE 0 END) AS reached_cart,
    MAX(CASE WHEN event_name = 'click_payment' THEN 1 ELSE 0 END) AS reached_payment
  FROM base
  GROUP BY user_pseudo_id
),

funnel AS (
  SELECT
    COUNT(DISTINCT CASE WHEN reached_welcome = 1 THEN user_pseudo_id END) AS step1_welcome,
    COUNT(DISTINCT CASE WHEN reached_login = 1 THEN user_pseudo_id END) AS step2_login,
    COUNT(DISTINCT CASE WHEN reached_explore = 1 THEN user_pseudo_id END) AS step3_explore,
    COUNT(DISTINCT CASE WHEN reached_restaurant = 1 THEN user_pseudo_id END) AS step4_restaurant,
    COUNT(DISTINCT CASE WHEN reached_cart = 1 THEN user_pseudo_id END) AS step5_cart,
    COUNT(DISTINCT CASE WHEN reached_payment = 1 THEN user_pseudo_id END) AS step6_payment
  FROM user_journey
)

-- 단계별/전체 전환율
SELECT
  'Step 1: Welcome' AS step,
  step1_welcome AS users, 100.0 AS conversion_from_prev, 100.0 AS conversion_from_start
FROM funnel
UNION ALL
SELECT 'Step 2: Login', step2_login,
  ROUND(100.0 * step2_login / step1_welcome, 2),
  ROUND(100.0 * step2_login / step1_welcome, 2)
FROM funnel
UNION ALL
SELECT 'Step 3: Explore (Category/Search/Banner/Nearby)', step3_explore,
  ROUND(100.0 * step3_explore / step2_login, 2),
  ROUND(100.0 * step3_explore / step1_welcome, 2)
FROM funnel
UNION ALL
SELECT 'Step 4: Restaurant', step4_restaurant,
  ROUND(100.0 * step4_restaurant / step3_explore, 2),
  ROUND(100.0 * step4_restaurant / step1_welcome, 2)
FROM funnel
UNION ALL
SELECT 'Step 5: Cart', step5_cart,
  ROUND(100.0 * step5_cart / step4_restaurant, 2),
  ROUND(100.0 * step5_cart / step1_welcome, 2)
FROM funnel
UNION ALL
SELECT 'Step 6: Payment', step6_payment,
  ROUND(100.0 * step6_payment / step5_cart, 2),
  ROUND(100.0 * step6_payment / step1_welcome, 2)
FROM funnel
ORDER BY step;
