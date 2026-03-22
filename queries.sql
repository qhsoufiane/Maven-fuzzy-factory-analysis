-- =====================================================
-- QUERY 1: Funnel Drop-off by Device Type
-- Objective:
-- Analyze user progression through the conversion funnel
-- (product → cart → shipping → billing → purchase)
-- segmented by device (desktop vs mobile)
-- =====================================================

WITH funnel_drop_off AS (

SELECT 
    COUNT(DISTINCT s.website_session_id) AS total_sessions,
    s.device_type,

    COUNT(DISTINCT CASE 
        WHEN p.pageview_url = '/products' 
        THEN p.website_session_id END) AS product_sessions,

    COUNT(DISTINCT CASE 
        WHEN p.pageview_url = '/cart' 
        THEN p.website_session_id END) AS cart_sessions,

    COUNT(DISTINCT CASE 
        WHEN p.pageview_url = '/shipping' 
        THEN p.website_session_id END) AS shipping_sessions,

    COUNT(DISTINCT CASE 
        WHEN p.pageview_url IN ('/billing','/billing-2')  
        THEN p.website_session_id END) AS billing_sessions,

    COUNT(DISTINCT CASE 
        WHEN p.pageview_url = '/thank-you-for-your-order' 
        THEN p.website_session_id END) AS purchase_sessions

FROM website_sessions s
LEFT JOIN website_pageviews p 
    ON s.website_session_id = p.website_session_id

WHERE s.is_repeat_session = 0 
  AND s.utm_source IS NOT NULL

GROUP BY s.device_type
)

SELECT 
    device_type,
    total_sessions,
    product_sessions,
    cart_sessions,
    shipping_sessions,
    billing_sessions,
    purchase_sessions,

    -- Conversion rates
    product_sessions * 1.0 / total_sessions AS product_rate,
    cart_sessions * 1.0 / product_sessions AS cart_rate,
    purchase_sessions * 1.0 / total_sessions AS overall_conversion_rate

FROM funnel_drop_off
ORDER BY total_sessions DESC;

-- =====================================================
-- Insight:
-- Desktop users show higher progression across the funnel
-- compared to mobile users, suggesting potential UX or
-- performance issues on mobile devices.
-- =====================================================


-- =====================================================
-- QUERY 2: Sessions Reaching Each Funnel Step
-- Objective:
-- Measure how many sessions reach each key page
-- (home → products → shipping → purchase)
-- and compare behavior by device type
-- =====================================================

WITH session_flags AS (

SELECT 
    s.website_session_id,
    s.device_type,

    MAX(CASE WHEN p.pageview_url = '/home' THEN 1 ELSE 0 END) AS saw_home,
    MAX(CASE WHEN p.pageview_url = '/products' THEN 1 ELSE 0 END) AS saw_products,
    MAX(CASE WHEN p.pageview_url = '/shipping' THEN 1 ELSE 0 END) AS saw_shipping,
    MAX(CASE WHEN p.pageview_url = '/thank-you-for-your-order' THEN 1 ELSE 0 END) AS made_purchase

FROM website_sessions s
LEFT JOIN website_pageviews p
    ON s.website_session_id = p.website_session_id

WHERE s.is_repeat_session = 0
  AND s.utm_source IS NOT NULL

GROUP BY 
    s.website_session_id,
    s.device_type
)

SELECT 
    device_type,

    COUNT(DISTINCT website_session_id) AS total_sessions,
    SUM(saw_home) AS home_sessions,
    SUM(saw_products) AS product_sessions,
    SUM(saw_shipping) AS shipping_sessions,
    SUM(made_purchase) AS purchase_sessions,

    -- Conversion rates
    SUM(saw_products) * 1.0 / COUNT(DISTINCT website_session_id) AS home_to_product_rate,
    SUM(saw_shipping) * 1.0 / SUM(saw_products) AS product_to_shipping_rate,
    SUM(made_purchase) * 1.0 / COUNT(DISTINCT website_session_id) AS overall_conversion_rate

FROM session_flags
GROUP BY device_type
ORDER BY total_sessions DESC;

-- =====================================================
-- Insight:
-- A significant drop occurs between product and shipping stages,
-- particularly on mobile devices, highlighting potential friction
-- in the mid-funnel experience.
-- =====================================================

-- =====================================================
-- QUERY 3: Marketing Traffic by Source and Device
-- Objective:
-- Analyze acquisition performance by traffic source
-- and device type, and compare ad-content distribution.
-- =====================================================

SELECT
    s.utm_source,
    s.device_type,
    COUNT(DISTINCT s.website_session_id) AS total_sessions,

    COUNT(DISTINCT CASE
        WHEN s.utm_content = 'g_ad_1' THEN s.website_session_id
    END) AS google_ad_sessions,

    COUNT(DISTINCT CASE
        WHEN s.utm_content = 'b_ad_1' THEN s.website_session_id
    END) AS bing_ad_sessions,

    COUNT(DISTINCT CASE
        WHEN s.utm_campaign IS NOT NULL THEN s.website_session_id
    END) AS campaign_sessions

FROM website_sessions s
WHERE s.is_repeat_session = 0
  AND s.utm_source IS NOT NULL
GROUP BY
    s.utm_source,
    s.device_type
ORDER BY total_sessions DESC;

-- =====================================================
-- Insight:
-- Traffic acquisition is concentrated in a limited number
-- of paid sources and varies by device type, highlighting
-- where marketing performance should be optimized.
-- =====================================================

-- =====================================================
-- QUERY 4: Session-to-Order Conversion by Device Type
-- Objective:
-- Measure how many sessions generated an order
-- and compare conversion performance across devices.
-- =====================================================

SELECT
    s.device_type,
    COUNT(DISTINCT s.website_session_id) AS total_sessions,
    COUNT(DISTINCT o.website_session_id) AS ordering_sessions,

    COUNT(DISTINCT o.website_session_id) * 1.0
        / COUNT(DISTINCT s.website_session_id) AS session_to_order_conversion_rate

FROM website_sessions s
LEFT JOIN orders o
    ON s.website_session_id = o.website_session_id

WHERE s.is_repeat_session = 0

GROUP BY s.device_type
ORDER BY total_sessions DESC;

-- =====================================================
-- Insight:
-- Desktop sessions convert into orders at a higher rate
-- than mobile sessions, reinforcing the hypothesis of
-- stronger purchase friction on mobile devices.
-- =====================================================

-- =====================================================
-- QUERY 5: Orders by Product
-- Objective:
-- Identify which products generate the highest number
-- of orders and evaluate product concentration.
-- =====================================================

SELECT
    p.product_name,
    COUNT(DISTINCT o.order_id) AS total_orders

FROM orders o
LEFT JOIN products p
    ON o.primary_product_id = p.product_id

GROUP BY p.product_name
ORDER BY total_orders DESC;

-- =====================================================
-- Insight:
-- Order volume is concentrated on a small number of products,
-- with one product clearly outperforming the others, which
-- suggests strong product-market fit but also concentration risk.
-- =====================================================

-- =====================================================
-- QUERY 6: Product Page Performance by Device Type
-- Objective:
-- Analyze how different product pages perform across devices
-- by measuring the number of sessions reaching each product page.
-- =====================================================

SELECT
    s.device_type,

    COUNT(DISTINCT CASE 
        WHEN p.pageview_url = '/the-original-mr-fuzzy' 
        THEN p.website_session_id END) AS mr_fuzzy_sessions,

    COUNT(DISTINCT CASE 
        WHEN p.pageview_url = '/the-forever-love-bear' 
        THEN p.website_session_id END) AS forever_love_sessions,

    COUNT(DISTINCT CASE 
        WHEN p.pageview_url = '/the-birthday-sugar-panda' 
        THEN p.website_session_id END) AS birthday_panda_sessions,

    COUNT(DISTINCT CASE 
        WHEN p.pageview_url = '/the-hudson-river-mini-bear' 
        THEN p.website_session_id END) AS hudson_mini_sessions

FROM website_sessions s
LEFT JOIN website_pageviews p
    ON s.website_session_id = p.website_session_id

WHERE s.is_repeat_session = 0

GROUP BY s.device_type
ORDER BY s.device_type;

-- =====================================================
-- Insight:
-- Product page engagement varies by device, with certain
-- products receiving significantly more traffic, highlighting
-- strong product preference and potential optimization opportunities.
-- =====================================================
