-- In this case, the materialization config set at the "dbt_project" level is overriden
-- The model is stored as a table because it is not redundant
{{ config(
    materialized='incremental',
    unique_key = 'transaction_id',
    incremental_strategy='merge'
    ) 
}}

-- This model stores all records where the field "quantity" is missing at the source
-- Since no specific patterns as to why there exist missing values were identified, this table could be used to develop imputation ML models (provided that people on the operational side are of no help)
WITH bronze AS (
    SELECT *
    FROM {{ ref('customer_transactions') }}
    WHERE quantity IS NULL
)

SELECT *
FROM bronze