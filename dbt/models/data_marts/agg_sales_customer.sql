{{ config(materialized='view') }}

WITH transaction_fct AS (
  SELECT *
  FROM {{ ref('transaction_fct') }}
),

customer_dim AS (
  SELECT *
  FROM {{ ref('customer_dim') }}
)

SELECT
  b.id AS customer_id,
  ROUND(SUM(a.quantity * a.price)::NUMERIC, 2) AS revenue
FROM transaction_fct AS a
JOIN customer_dim AS b
ON a.customer_id = b.id
GROUP BY 1