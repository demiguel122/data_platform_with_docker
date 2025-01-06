# Data Platform [Airflow, dbt] with Docker

## Table of contents

* [Brief Introduction]()
* [Deployment]()
* [Platform specifications]()
* [Pipeline specifications]()
  * [DAG workflow]()
  * [dbt workflow]()
  * [Issues encountered]()
  * [Other aspects: Incrementality, Testing, etc]()
* [Ideas for further improvement]()
* [Contact]()
  
-------------------

## Brief Introduction

This project is a modest attempt at creating a scalable and performant data platform using Airflow, dbt and Docker. It also includes a very simple data pipeline that leverages a medallion architecture. 

This is by no means a ready-for-production data platform, just a little mockup project that could indeed be improved in many ways.

## Deployment

The full project is deployable via `docker-compose up`. Once deployed, trigger the DAG manually.

All the required elements are attached in this repo, including a small .csv file containing the data to be extracted, loaded and transformed. Nothing else is required on the user's end.

> [!WARNING]
> If you are using the "Power User for dbt" VS Code extension, you must disable it before executing `docker-compose up`, since it misinteracts with the "dbt deps" command, causing it to fail.

## Platform specifications

The Data Platform has three main components:

- **Airflow**: Used to orchestrate the whole pipeline. In our case, we will be using a 3-node Airflow cluster leveraging the `CeleryExecutor`. Redis is used as a message broker. The objective of such setup is to distibute workloads across different worker nodes for parallel task execution.
    
- **dbt**: used for transforming the raw data throughout the different layers of a medallion architecture. We will be using the `dbt-postgres` connector.

-  **Docker**: the whole infrastructure will be deployed and managed via the `docker-compose.yml` file. These are the containers/services deployed:

    - `postgres-airflow`: metadata database for the Airflow instance
    - `airflow-webserver`: GUI
    - `airflow-scheduler`: monitors and triggers the DAGs. In a multi-node cluster, it also distributes tasks across worker nodes
    - `airflow-worker`: Executes the DAG tasks. This project will scale out 3 replicas
    - `redis`: message broker used for communication between the main Airflow components
    - `dbt`: transformation tool
    - `postgres-dbt`: we will use postgres databases to store all raw and transformed data. More specifically, the following databases will be created during deployment using the `init_postgres_dbt.sql` file as an entrypoint:
      
      - `data_lake`: will contain all raw data as-is. This is the target database where our DAG will load the extracted data. dbt will not materialize any models here. It will be read-only.
      - `dev`: database used for the development environment
      - `pro`: database used for the production environment
      
Below you can a find the corresponding architecture diagram:

<p align="center">
  <img src="https://github.com/user-attachments/assets/5a7efeb1-572c-4b46-af96-15296e211612">
</p>

## Pipeline specifications

### DAG workflow

The DAG `forex__customer_transactions__hourly.py` is comprised of three tasks:
  
  - **Extract**: the first task of the DAG splits the .csv file in chunks and saves each chunk as a separate file in a local temporary directory created ad-hoc.
 
  - **Load**: this task dynamically generates a MERGE statement for each chunk to perform upsert operations into the target `data_lake` database located in the `postgres-dbt` container. It leverages Airflow's Dynamic Task Mapping to load the .csv chunks in parallel. It also instructs Postgres to generate a "load_timestamp" value for each inserted/updated record. This will be used by incremental models in dbt.
 
  - **Transform**: uses the `SSHOperator` to trigger the `dbt deps` and `dbt build --target pro` commands in dbt.

### dbt workflow

As briefly mentioned above, the data platform contains three distinct databases under the `postgres-dbt` container: `data_lake`, `dev` and `pro`. 

Data will be ingested into `data_lake` via Airflow, and then dbt will read from those data and materialize into `dev` or `pro`, depending on the `--target` specified. 

If the target is `dev`, models will be materialized in the `dev.<user>_<directory_name>` schema. For instance: a model located in the `dbt/models/silver` directory will be materialized in the schema `dev.<user>_silver`. Whenever the target is `pro`, materializations will be performed in the `pro.<directory_name>` schema. For instance: a model located in the `dbt/models/silver` directory will be materialized in the schema `pro.silver`.

For each database connected to dbt, we follow a medallion DWH architecture where data is stored in three different layers: bronze (raw), silver (cleaned) and gold (facts and dimensions). After that, different data marts with aggregate views are created for consumption by the business.

<p align="center">
  <img src="https://github.com/user-attachments/assets/306a98a3-a796-4a39-be7d-504c6a92c4c1">
</p>

Below you can find a diagram showing the schemas for the different models in each layer (bronze, silver, gold).

<p align="center">
  <img src="https://github.com/user-attachments/assets/661da6c4-01d8-49dc-8859-6224e4d32331">
</p>

### Issues encountered

The source data had some missing values and inconsistencies:

- The fields `price` and `tax` were supposed to contain FLOAT values, but there were instances where they contained number words (e.g. "Two Hundred" or "fifteen"). To solve this issue, a function `Word2Number` is created during database setup that converts such values to their numeric equivalent.

- There where some missing values in the `quantity` field. Since no apparent explaining pattern was found, the ideal solution in a real-life scenario would be contacting people managing the operational system to find out whether the issue is on their side. In case they are of no help, ML imputation methods can be developed. For that end, all such records are materialized into a dbt model called `missing_quantity`, so that they can serve to feed this hypothetical ML pipeline.

-  To avoid problems in case the UUIDs generated in the OLTP system changed, we produce primary and foreign keys using (composite, when possible) natural keys, which are less prone to change than their operational counterparts. This way, we effectively discard operational UUIDs and ensure referential integrity regardless of the existence of missing values for these fields in the raw data.

### Other aspects: Incrementality, and Testing

Except for the bronze layer, which is materialized as a view to avoid redundancies, and all data marts models (also materialized as views), the remaining models are materialized as incremental tables to allow for efficiency. The `incremental_strategy` was set to `merge`. Note that, in order to leverage incrementality, a `load_timestamp` field was introduced in every model.

All models have their respective `not_null`, `unique` and `relationships` tests implemented.

## Ideas for further improvement

The scalability and performance of the platform could be improved, amongst other, implementing the following:

- PostgreSQL's Read Replicas: 

- Citus for PostgreSQL:

For security improvements:

-  Docker Secrets:

For resource and performance tracking:

- ELK stack for monitoring/diagnostics against log files.

- Prometheus and Grafana for metrics collection.

For CI/CD:

- Github Actions:

## Contact

- **Linkedin**: [https://www.linkedin.com/in/albertodemiguel/](https://www.linkedin.com/in/albertodemiguel/)
- **Email**: [ademiguellechuga@gmail.com](ademiguellechuga@gmail.com)
