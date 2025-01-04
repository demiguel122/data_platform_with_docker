{{ config(
    materialized='incremental',
    unique_key = 'transaction_id',
    incremental_strategy='merge'
    ) 
}}

WITH bronze AS (
    SELECT *
    FROM {{ ref('customer_transactions') }}
    WHERE quantity IS NULL
)

SELECT *
FROM bronze