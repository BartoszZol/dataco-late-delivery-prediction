USE dataco;

-- Supply chain data
/* Character set for latin1 due to text formating
order dates set to '%m/%d/%Y %H:%i'
zipcodes switched to nulls when empty */

LOAD DATA INFILE
'C:/ProgramData/MySQL/MySQL Server 8.0/Uploads/dataset_dataco/DataCoSupplyChainDataset.csv'
INTO TABLE supply_chain
CHARACTER SET latin1
FIELDS TERMINATED BY ','
ENCLOSED BY '"'
LINES TERMINATED BY '\r\n'
IGNORE 1 ROWS
(
    payment_type,
    days_for_shipping_real,
    days_for_shipment_scheduled,
    benefit_per_order,
    sales_per_customer,
    delivery_status,
    late_delivery_risk,
    category_id,
    category_name,
    customer_city,
    customer_country,
    customer_email,
    customer_fname,
    customer_id,
    customer_lname,
    customer_password,
    customer_segment,
    customer_state,
    customer_street,
    @customer_zipcode,
    department_id,
    department_name,
    latitude,
    longitude,
    market,
    order_city,
    order_country,
    order_customer_id,
    @order_date,
    order_id,
    order_item_cardprod_id,
    order_item_discount,
    order_item_discount_rate,
    order_item_id,
    order_item_product_price,
    order_item_profit_ratio,
    order_item_quantity,
    sales,
    order_item_total,
    order_profit_per_order,
    order_region,
    order_state,
    order_status,
    @order_zipcode,
    product_card_id,
    product_category_id,
    product_description,
    product_image,
    product_name,
    product_price,
    product_status,
    @shipping_date,
    shipping_mode
)
SET
	order_date = STR_TO_DATE(@order_date, '%m/%d/%Y %H:%i'),
    shipping_date = STR_TO_DATE(@shipping_date, '%m/%d/%Y %H:%i'),
    order_zipcode = NULLIF(@order_zipcode, ''),
    customer_zipcode = NULLIF(@customer_zipcode, '');

-- Access logs data
LOAD DATA INFILE 
'C:/ProgramData/MySQL/MySQL Server 8.0/Uploads/dataset_dataco/tokenized_access_logs.csv'
INTO TABLE tokenized_access_logs
FIELDS TERMINATED BY ','
LINES TERMINATED BY '\r\n'
IGNORE 1 ROWS
(
    product,
    category,
    @log_Date,
    log_Month,
    log_Hour,
    department,
    ip,
    url
)
SET 
	log_Date = STR_TO_DATE(@log_Date, '%m/%d/%Y %H:%i');
