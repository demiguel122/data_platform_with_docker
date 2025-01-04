{{ config(materialized='view') }}

WITH transaction_fct AS (
  SELECT *
  FROM {{ ref('transaction_fct') }}
),

date_dim AS (
  SELECT *
  FROM {{ ref('date_dim') }}
)

SELECT
  b.year_number AS year,
  b.month_of_year AS month,
  b.quarter_of_year AS quarter,
  ROUND(SUM(a.quantity * a.price)::NUMERIC, 2) AS monthly_revenue
FROM transaction_fct AS a
JOIN date_dim AS b
ON a.transaction_date = b.date
GROUP BY 1, 2, 3