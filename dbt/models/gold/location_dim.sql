{{ config(
    materialized='incremental',
    unique_key = 'id',
    incremental_strategy='merge'
    ) 
}}

WITH silver AS (
    SELECT DISTINCT
        customer_location_id AS id,
        customer_city AS city,
        customer_country AS country
    FROM {{ ref('transaction') }}

    {% if is_incremental() %}
        WHERE transaction.load_timestamp > (SELECT MAX(this.load_timestamp) FROM {{ this }} AS this)
    {% endif %}
)

SELECT 
    *,
    CURRENT_TIMESTAMP AS load_timestamp
FROM silver