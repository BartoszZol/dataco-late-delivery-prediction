CREATE TABLE supply_chain_backup AS
SELECT * FROM supply_chain;

-- canceled shippings contributed noise between late/on-time and carry no
-- signal for the analyzed problem (4.3% of rows)
DELETE FROM supply_chain 
WHERE delivery_status = 'Shipping canceled';

-- deleting noise columns without value for analysis target
ALTER TABLE supply_chain
DROP COLUMN delivery_status,
DROP COLUMN days_for_shipping_real,
DROP COLUMN customer_email,
DROP COLUMN customer_password,
DROP COLUMN customer_fname,
DROP COLUMN customer_lname,
DROP COLUMN customer_street,
DROP COLUMN customer_id,
DROP COLUMN order_id,
DROP COLUMN product_description,
DROP COLUMN product_image,
DROP COLUMN category_id,
DROP COLUMN product_card_id,
DROP COLUMN order_item_cardprod_id,
DROP COLUMN order_zipcode,
DROP COLUMN customer_zipcode;