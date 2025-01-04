from airflow.decorators import dag, task
from pendulum import datetime, duration
from airflow.providers.postgres.hooks.postgres import PostgresHook
from airflow.providers.ssh.operators.ssh import SSHOperator
from airflow.hooks.base_hook import BaseHook
import os
import pandas as pd

# Note the absence of top-level DAG code
# This is done to avoid the Airflow scheduler from executing this code at least every 30s rather than when the DAG is scheduled to run, causing unnecessary stress on the infrastructure

@dag(
    dag_id="FOREX__CUSTOMER_TRANSACTIONS__HOURLY",      # DAG nomenclature: <company_division>__<pipeline>__<schedule_interval>
    description="This DAG implements a full, scalable and memory-efficient ELT pipeline orchestration setup to load .csv data containing customer transaction data into a PostgreSQL database and transform it using dbt.",
    tags=["forex", "transactions", "hourly"],
    owner_links={"data_platform_engineer": "mailto:data_platform_engineer@fintech_company.com"},
    start_date=datetime(2025, 1, 1),
    schedule_interval=None,     # Set to none for the sake of convenience. Simply trigger manually when deploying
    catchup=False,
    default_args={
        "retries": 3,
        "retry_delay": duration(minutes=1),
        "max_retry_delay": duration(minutes=15)
    }
)
def orchestrator():
        
    # Splits the .csv file in chunks, saves each chunk as a separate file in a local temporary directory created ad-hoc and returns the path to each chunk
    @task
    def extract(file_path: str, chunk_size: int) -> list:
        file_name_with_extension = os.path.basename(file_path)
        file_name_without_extension = os.path.splitext(file_name_with_extension)[0]
        temp_dir = "/opt/airflow/data/temp_chunks"
        os.makedirs(temp_dir, exist_ok=True)
        chunk_paths = []
        
        for i, chunk in enumerate(pd.read_csv(file_path, chunksize=chunk_size), start=1):
            chunk_path = os.path.join(temp_dir, f"{file_name_without_extension}__chunk_{i}.csv")
            chunk.to_csv(chunk_path, index=False)
            chunk_paths.append(chunk_path)
        return chunk_paths

    # Dynamically generates a MERGE statement for each chunk to perform upsert operations into the target Postgres database
    # This task is intended to leverage Airflow's Dynamic Task Mapping to load the csv chunks in parallel (see the use of the "expand" method below)
    # Note that it also instructs Postgres to generate a "load_timestamp" value for each inserted/updated record. This will be used by incremental models in dbt.
    @task      
    def load(chunk_path: str, target_table: str, primary_key: str):
        postgres_hook = PostgresHook(postgres_conn_id='postgres_dbt_conn')

        df = pd.read_csv(chunk_path)
        df = df.where(pd.notna(df), None)

        csv_columns = df.columns.tolist()
        table_columns = csv_columns

        values_clause = ", ".join(
        f"({', '.join([repr(row[col]) if not pd.isna(row[col]) else 'NULL' for col in csv_columns])})"  # Converts missing values to SQL NULL's
        for _, row in df.iterrows()
        )

        merge_query = f"""
        MERGE INTO {target_table} AS target
        USING (VALUES {values_clause}) AS source (
            {', '.join(table_columns)}
        )
        ON target.{primary_key} = source.{primary_key}
        WHEN MATCHED THEN
            UPDATE SET
                {', '.join([f"{col} = source.{col}" for col in table_columns if col != primary_key])},
                load_timestamp = CURRENT_TIMESTAMP
        WHEN NOT MATCHED THEN
            INSERT ({', '.join(table_columns)}, load_timestamp)
            VALUES ({', '.join([f"source.{col}" for col in table_columns])}, CURRENT_TIMESTAMP);
        """

        postgres_hook.run(merge_query)

        os.remove(chunk_path)  # Clean up the temporary file after loading
    
    # Retrieves "extra" connection details as a JSON object
    # This is necessary because, eventhough the necessary environment variables are set in the dbt container with docker-compose, the SSHOperator opens a non-interactive shell
    # This results in remote environment variables not being sourced, so they must be passed using the "environment" parameter below
    dbt_conn_extra = BaseHook.get_connection('dbt_conn').extra_dejson

    # Triggers the dbt transformation process targeting the production environment defined in the profiles.yml file
    # Prior to that, installs all necessary dependencies included in the packages.yml file
    # IMPORTANT: if you are using the "Power User for dbt" VS Code extension, you must disable it before executing "docker-compose build", since it misinteracts with the "dbt deps" command, causing it to fail
    transform = SSHOperator(
        task_id='transform',
        ssh_conn_id='dbt_conn',
        command="""
        cd /usr/app &&
        dbt deps &&
        dbt build --target pro
        """,
        environment=dbt_conn_extra,
        cmd_timeout=600
    )

    # Task dependencies
    chunk_files = extract(file_path='/opt/airflow/data/customer_transactions.csv', chunk_size=10)
    load_task = load.expand(chunk_path=chunk_files, target_table=['forex.customer_transactions'], primary_key =['transaction_id'])
    load_task >> transform

# Instantiates the dag
orchestrator()