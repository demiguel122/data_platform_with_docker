-- Materialized as a view so as to not have a redundandt copy of the data already sotred in the "data_lake" database
-- This config is already set at the "dbt_project" level, so it is actually redundant here. It was kept for clarity
{{ config(materialized='view') }}

-- Uses DBLINK to connect to establish a connection with a different database
-- The data is stored as-is
WITH source AS (
  SELECT
    transaction_id,
    customer_id ,
    transaction_date,
    product_id,
    product_name,
    quantity,
    price,
    tax,
    customer_first_name,
    customer_last_name,
    customer_email,
    customer_phone,
    customer_country,
    customer_city,
    load_timestamp
  FROM dblink(
    'host=' || '{{ var("dblink_host") }}' || 
    ' dbname=' || '{{ var("dblink_dbname") }}' || 
    ' user=' || '{{ var("dblink_user") }}' || 
    ' password=' || '{{ var("dblink_password") }}',
    'SELECT 
      transaction_id, 
      customer_id, 
      transaction_date, 
      product_id, 
      product_name, 
      quantity, 
      price, 
      tax,
      customer_first_name,
      customer_last_name,
      customer_email,
      customer_phone,
      customer_country,
      customer_city,
      load_timestamp
     FROM forex.customer_transactions'
  ) AS remote_data(
    transaction_id VARCHAR,
    customer_id FLOAT,
    transaction_date VARCHAR,
    product_id VARCHAR,
    product_name VARCHAR,
    quantity FLOAT,
    price VARCHAR,
    tax VARCHAR,
    customer_first_name VARCHAR,
    customer_last_name VARCHAR,
    customer_email VARCHAR,
    customer_phone VARCHAR,
    customer_country VARCHAR,
    customer_city VARCHAR,
    load_timestamp TIMESTAMP
  )
)

SELECT *
FROM source