{{ config(
    materialized='incremental',
    unique_key = 'id',
    incremental_strategy='merge'
    ) 
}}

WITH silver AS (
    SELECT DISTINCT
        product_id AS id,
        product_name AS name
    FROM {{ ref('transaction') }}

    {% if is_incremental() %}
        WHERE transaction.load_timestamp > (SELECT MAX(this.load_timestamp) FROM {{ this }} AS this)
    {% endif %}
)

SELECT 
    *,
    CURRENT_TIMESTAMP AS load_timestamp
FROM silver