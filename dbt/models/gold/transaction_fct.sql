{{ config(
    materialized='incremental',
    unique_key = 'transaction_id',
    incremental_strategy='merge'
    ) 
}}

WITH silver AS (
  SELECT
    transaction_id,
    customer_id,
    product_id,
    customer_location_id,
    transaction_date,
    quantity,
    price,
    tax,
    CURRENT_TIMESTAMP AS load_timestamp
  FROM {{ ref('transaction') }}
  
  {% if is_incremental() %}
    WHERE transaction.load_timestamp > (SELECT MAX(this.load_timestamp) FROM {{ this }} AS this)
  {% endif %}
)

SELECT *
FROM silver