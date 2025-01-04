{{ config(
    materialized='incremental',
    unique_key = 'id',
    incremental_strategy='merge'
    ) 
}}

WITH silver AS (
    SELECT DISTINCT
        customer_id AS id,
        customer_first_name AS first_name,
        customer_last_name AS last_name,
        customer_email AS email,
        customer_phone AS phone,
        customer_country AS country,
        customer_city AS city
    FROM {{ ref('transaction') }}

    {% if is_incremental() %}
        WHERE transaction.load_timestamp > (SELECT MAX(this.load_timestamp) FROM {{ this }} AS this)
    {% endif %}
)

SELECT 
    *,
    CURRENT_TIMESTAMP AS load_timestamp
FROM silver