# Data Platform [Airflow, dbt] with Docker

## Table of contents

* [Brief Introduction]()
* [Deployment]()
* [Platform specifications]()
* [Pipeline specifications]()
  * [DAG workflow]()
  * [dbt workflow]()
  * [Data models per layer]()
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
      
      - `data_lake`: will contain all raw data as-is. This is the target database where our DAG will load the extracted data. dbt will not materialize any models here. It will only read.
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

### Data models per layer

Below you can find a diagram showing the schemas for the different models in each layer (bronze, silver, gold).

<p align="center">
  <img src="https://github.com/user-attachments/assets/661da6c4-01d8-49dc-8859-6224e4d32331">
</p>

### Other aspects: Incrementality, Testing, etc







## Ideas for further improvement






## Contact

- **Linkedin**: [https://www.linkedin.com/in/albertodemiguel/](https://www.linkedin.com/in/albertodemiguel/)
- **Email**: [ademiguellechuga@gmail.com](ademiguellechuga@gmail.com)
