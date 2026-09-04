-- order zipcodes NULL check (valid)
SELECT
    COUNT(*) AS total_rows,
    COUNT(order_zipcode) AS with_zipcode,
    COUNT(*) - COUNT(order_zipcode) AS without_zipcode
FROM supply_chain;

-- URL truncating check
SELECT MAX(CHAR_LENGTH(url)) AS max_url_length
FROM tokenized_access_logs;

-- product name truncating check
SELECT MAX(CHAR_LENGTH(Product)) AS max_product_length
FROM tokenized_access_logs;

SELECT COUNT(order_item_id), COUNT(DISTINCT(order_item_id)) FROM supply_chain;

-- category  balace check
SELECT 
	late_delivery_risk, 
    delivery_status,
	COUNT(*) AS orders, 
	ROUND(COUNT(*) * 100.0 / SUM(COUNT(*)) OVER (), 2) AS percentage
FROM supply_chain
GROUP BY late_delivery_risk, delivery_status
ORDER BY late_delivery_risk;

-- late delivery risk check 
SELECT
    late_delivery_risk,
	CASE
		WHEN days_for_shipping_real > days_for_shipment_scheduled
			THEN 1
            ELSE 0
	END AS calculated_late,
    COUNT(*) AS orders
FROM supply_chain
GROUP BY
    late_delivery_risk,
    calculated_late
ORDER BY
    late_delivery_risk,
    calculated_late;

-- Shipping canceled calculation check
    SELECT delivery_status,
       CASE WHEN days_for_shipping_real > days_for_shipment_scheduled THEN 1 ELSE 0 END AS calculated_late,
       COUNT(*) AS orders
FROM supply_chain
GROUP BY delivery_status, calculated_late
ORDER BY delivery_status, calculated_late;

-- Category check
SELECT COUNT(*) AS mismatches
FROM supply_chain
WHERE category_id <> product_category_id;