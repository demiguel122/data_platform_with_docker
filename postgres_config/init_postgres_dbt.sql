CREATE DATABASE data_lake;
CREATE DATABASE dev;
CREATE DATABASE pro;

\c data_lake;

SET timezone = 'UTC';

CREATE SCHEMA IF NOT EXISTS forex;

CREATE TABLE IF NOT EXISTS forex.customer_transactions (
    transaction_id VARCHAR(20) PRIMARY KEY,
    customer_id FLOAT,
    transaction_date VARCHAR(20),
    product_id VARCHAR(20),
    product_name VARCHAR(100),
    quantity FLOAT,
    price VARCHAR(20),
    tax VARCHAR(20),
    customer_first_name VARCHAR(100),
    customer_last_name VARCHAR(100),
    customer_email VARCHAR(100),
    customer_phone VARCHAR(100),
    customer_country VARCHAR(100),
    customer_city VARCHAR(100),
    load_timestamp TIMESTAMP
);

\c dev;

SET timezone = 'UTC';

CREATE EXTENSION dblink;

CREATE OR REPLACE FUNCTION read_number(num NUMERIC) 
RETURNS VARCHAR 
LANGUAGE SQL 
IMMUTABLE STRICT 
AS 
$$
SELECT  
    LOWER(
        TRIM(
            REPLACE(
                REGEXP_REPLACE(
                    CASH_WORDS(num::money),
                    ' dollar.*',--cut out currency and fractions
                    ''
                ),
                '  ',--remove accidental double spaces
                ' ' 
            )
        )
    )
$$;

CREATE TABLE number_readings AS 
    SELECT num,read_number(num) AS num_reading
    FROM generate_series(0,2e5,1) AS a(num);

CREATE INDEX ON number_readings (num_reading) INCLUDE (num) WITH (fillfactor=100);

CREATE OR REPLACE FUNCTION word2number(txt varchar)
RETURNS VARCHAR 
LANGUAGE SQL 
IMMUTABLE STRICT 
AS 
$$
SELECT num*(CASE WHEN LOWER(txt) ~ '^minus.*' THEN -1 ELSE 1 END)
FROM number_readings 
WHERE num_reading=TRIM(
                    REPLACE(
                        REPLACE(
                            REPLACE(
                                LOWER(txt),
                                ' and',
                                ''),
                            '-',
                            ' '),
                        'minus ',
                        '')
                    );
$$;

\c pro;

SET timezone = 'UTC';

CREATE EXTENSION dblink;

CREATE OR REPLACE FUNCTION read_number(num NUMERIC) 
RETURNS VARCHAR 
LANGUAGE SQL 
IMMUTABLE STRICT 
AS 
$$
SELECT  
    LOWER(
        TRIM(
            REPLACE(
                REGEXP_REPLACE(
                    CASH_WORDS(num::money),
                    ' dollar.*',--cut out currency and fractions
                    ''
                ),
                '  ',--remove accidental double spaces
                ' ' 
            )
        )
    )
$$;

CREATE TABLE number_readings AS 
    SELECT num,read_number(num) AS num_reading
    FROM generate_series(0,2e5,1) AS a(num);

CREATE INDEX ON number_readings (num_reading) INCLUDE (num) WITH (fillfactor=100);

CREATE OR REPLACE FUNCTION word2number(txt varchar)
RETURNS VARCHAR 
LANGUAGE SQL 
IMMUTABLE STRICT 
AS 
$$
SELECT num*(CASE WHEN LOWER(txt) ~ '^minus.*' THEN -1 ELSE 1 END)
FROM number_readings 
WHERE num_reading=TRIM(
                    REPLACE(
                        REPLACE(
                            REPLACE(
                                LOWER(txt),
                                ' and',
                                ''),
                            '-',
                            ' '),
                        'minus ',
                        '')
                    );
$$;