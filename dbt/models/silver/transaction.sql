{{ config(
    materialized='incremental',
    unique_key = 'transaction_id',
    incremental_strategy='merge'
    ) 
}}

WITH source AS (
  SELECT *
  FROM {{ ref('customer_transactions') }}
  
  {% if is_incremental() %}
    WHERE customer_transactions.load_timestamp > (SELECT MAX(this.load_timestamp) FROM {{ this }} AS this)
  {% endif %}
),

cleaned_strings AS (
  SELECT
    NULLIF(TRIM(transaction_date), '') AS transaction_date,
    NULLIF(TRIM(product_name), '') AS product_name,
    quantity,
    NULLIF(TRIM(price), '') AS price,
    NULLIF(TRIM(tax), '') AS tax,
    NULLIF(TRIM(customer_first_name), '') AS customer_first_name,
    NULLIF(TRIM(customer_last_name), '') AS customer_last_name,
    NULLIF(TRIM(customer_email), '') AS customer_email,
    NULLIF(TRIM(customer_phone), '') AS customer_phone,
    NULLIF(TRIM(customer_country), '') AS customer_country,
    NULLIF(TRIM(customer_city), '') AS customer_city
  FROM source
),

transformed AS (
SELECT
  -- Converts all dates to a homogeneous date format, accounting for all possible input options
  TO_DATE(transaction_date,
    CASE 
      WHEN transaction_date ~ '^\d{4}-\d{2}-\d{2}$' THEN 'YYYY-MM-DD'
      WHEN transaction_date ~ '^\d{2}-\d{2}-\d{4}$' THEN 'DD-MM-YYYY'
      WHEN transaction_date ~ '^\d{2}/\d{2}/\d{4}$' THEN 'DD/MM/YYYY'
      WHEN transaction_date ~ '^\d{4}/\d{2}/\d{2}$' THEN 'YYYY/MM/DD'
      WHEN transaction_date ~ '^\d{2}-\d{2}-\d{2}$' THEN 'DD-MM-YY'
      WHEN transaction_date ~ '^\d{2}-\d{2}-\d{4}$' THEN 'MM-DD-YYYY'
      WHEN transaction_date ~ '^\d{2}/\d{2}/\d{4}$' THEN 'MM/DD/YYYY'
      WHEN transaction_date ~ '^\d{4}-\d{2}-\d{2} \d{2}:\d{2}:\d{2}$' THEN 'YYYY-MM-DD HH24:MI:SS'
      ELSE NULL
    END) AS transaction_date,
  product_name,
  quantity::INTEGER AS quantity,
  -- The Word2Number function is created during the Docker container build
  -- It is applied for every case where a price/tag value is composed of alphabetical characters
  -- Python libraries such as Word2Number are also an option, but Python cannot be executed in Postgres (bear in mind that this would be a feasible option in BigQuery/Snowflake)
  (CASE
    WHEN price ~ '^[A-Za-z -]+$' THEN Word2Number(price)
    ELSE price
  END)::FLOAT AS price,
  (CASE
    WHEN tax ~ '^[A-Za-z -]+$' THEN Word2Number(tax)
    ELSE tax
  END)::FLOAT AS tax,
  customer_first_name,
  customer_last_name,
  customer_email,
  customer_phone,
  customer_country,
  customer_city
FROM cleaned_strings
),

-- We produce primary and foreign keys using (composite, when possible) natural keys, which are less prone to change than the UUIDs generated in the operational system
-- This way, we effectively discard operational UUIDs and our models will always have unique keys regardless of the existence of missing values in the raw data
-- This also helps us:
        -- Ensure referential integrity if primary keys change in the operational system
        -- Remove the need to test for missing values for these fields at the bronze layer, focusing on the remaining columns
hashed AS (
  SELECT
  {{ dbt_utils.generate_surrogate_key(['customer_first_name', 'customer_last_name', 'customer_email', 'customer_phone', 'product_name', 'transaction_date']) }} AS transaction_id,
  {{ dbt_utils.generate_surrogate_key(['customer_first_name', 'customer_last_name', 'customer_email', 'customer_phone']) }} AS customer_id,
  {{ dbt_utils.generate_surrogate_key(['product_name']) }} AS product_id,
  transaction_date,
  product_name,
  customer_first_name,
  customer_last_name,
  customer_email,
  customer_phone,
  {{ dbt_utils.generate_surrogate_key(['customer_city', 'customer_country']) }} AS customer_location_id,
  customer_country,
  customer_city,
  quantity,
  price,
  tax,
  CURRENT_TIMESTAMP AS load_timestamp
FROM transformed
)

SELECT *
FROM hashed