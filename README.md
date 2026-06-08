# Movie Revenue Pipeline

End-to-end Snowflake data engineering project for ingesting daily movie revenue data, enriching it with OMDb API metadata, modelling it using dimensional modelling, and exposing a Streamlit ranking dashboard.

## Assumptions

This solution assumes that the source file `revenues_per_day.csv`
is uploaded manually to the Snowflake internal stage:

LIST @MOVIES_DB.BRONZE.REVENUE_STAGE;


## Architecture

The project follows the Medallion Architecture pattern:

CSV file
   ↓
Bronze layer
   - raw revenue data
   - raw OMDb API JSON

Silver layer
   - cleaned revenue data
   - flattened OMDb movie metadata
   - normalized OMDb ratings using LATERAL FLATTEN
   - enriched movie revenue view

Gold layer
   - DIM_MOVIE
   - DIM_DATE
   - FACT_DAILY_REVENUE
   - ranking view for dashboard

Streamlit
   - movie revenue ranking dashboard
   

## Deployment Order

Run the SQL scripts in the following order:

1. sql/0.0.0.Database_ddl.sql
2. sql/0.0.1.Api_ddl.sql

3. sql/0.1.Bronze_ddl.sql
4. sql/0.2.Silver_ddl.sql
5. sql/0.3.Gold_ddl.sql

6. sql/1.0.Bronze_procedures.sql
7. sql/2.0.Silver_procedures.sql
8. sql/3.0.Gold_procedures.sql

9. sql/4.0.Orchestration_tasks.sql

## To run end to end pipline please run:
EXECUTE TASK MOVIES_DB.ORCHESTRATION.TASK_LOAD_REVENUE;

## Pipeline execution flow:
TASK_LOAD_REVENUE
        ↓
TASK_LOAD_OMDB
        ↓
TASK_BUILD_SILVER
        ↓
TASK_BUILD_GOLD