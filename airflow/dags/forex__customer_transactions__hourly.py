from airflow.decorators import dag, task
from airflow.models import Variable
from airflow.models import Connection
from pendulum import datetime, duration
from airflow.providers.postgres.hooks.postgres import PostgresHook
from airflow.providers.ssh.operators.ssh import SSHOperator
from airflow.hooks.base_hook import BaseHook
import os
import pandas as pd

@dag(
    dag_id="FOREX__CUSTOMER_TRANSACTIONS__HOURLY",
    description="This DAG implements a full, scalable and memory-efficient pipeline orchestration setup to load .csv data into a PostgreSQL database.",
    tags=["FINANCE", "FX_TRANSFERS"],
    owner_links={"admin": "mailto:admin@example.com"},
    start_date=datetime(2023, 12, 20),
    schedule_interval=None,
    catchup=False,
    default_args={
        "retries": 3,
        "retry_delay": duration(minutes=1),
        "max_retry_delay": duration(minutes=15)
    }
)
def orchestrator():
        
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

    @task      
    def load(chunk_path: str, target_table: str, primary_key: str):
        postgres_hook = PostgresHook(postgres_conn_id='postgres_dbt_conn')

        df = pd.read_csv(chunk_path)
        df = df.where(pd.notna(df), None)

        csv_columns = df.columns.tolist()
        table_columns = csv_columns

        values_clause = ", ".join(
        f"({', '.join([repr(row[col]) if not pd.isna(row[col]) else 'NULL' for col in csv_columns])})"
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
    
    dbt_conn_extra = BaseHook.get_connection('dbt_conn').extra_dejson

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

    # Orchestration
    chunk_files = extract(file_path='/opt/airflow/data/customer_transactions.csv', chunk_size=10)
    load_task = load.expand(chunk_path=chunk_files, target_table=['forex.customer_transactions'], primary_key =['transaction_id'])
    load_task >> transform

orchestrator() # Instantiate the dag