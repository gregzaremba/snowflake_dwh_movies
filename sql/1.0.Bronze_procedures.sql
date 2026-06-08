CREATE OR REPLACE PROCEDURE MOVIES_DB.BRONZE.SP_LOAD_REVENUE_PER_DAY()
RETURNS STRING
LANGUAGE SQL
AS
$$
BEGIN

    COPY INTO MOVIES_DB.BRONZE.REVENUE_PER_DAY (
        ID,
        DATE,
        TITLE,
        REVENUE,
        THEATERS,
        DISTRIBUTOR,
        SOURCE_FILE
    )
    FROM (
        SELECT 
            $1::STRING,
            $2::DATE,
            $3::STRING,
            $4::NUMBER(18,0),
            $5::NUMBER(10,0),
            $6::STRING,
            METADATA$FILENAME
        FROM @MOVIES_DB.BRONZE.REVENUE_STAGE
    )
    FILE_FORMAT = MOVIES_DB.BRONZE.CSV_REVENUE_FORMAT
    ON_ERROR = CONTINUE
    FORCE = FALSE;

    RETURN 'Revenue per day load completed';

END;
$$;

--External access is not supported for trial accounts

CREATE OR REPLACE PROCEDURE MOVIES_DB.BRONZE.SP_LOAD_OMDB_MOVIES_FROM_API()
RETURNS STRING
LANGUAGE PYTHON
RUNTIME_VERSION = '3.11'
PACKAGES = ('snowflake-snowpark-python', 'requests')
HANDLER = 'main'
EXTERNAL_ACCESS_INTEGRATIONS = (OMDB_EXTERNAL_ACCESS_INTEGRATION)
SECRETS = ('omdb_api_key' = MOVIES_DB.BRONZE.OMDB_API_KEY_SECRET)
AS
$$
import json
import requests
from _snowflake import get_generic_secret_string

def main(session):

    api_key = get_generic_secret_string('omdb_api_key')

    titles = session.sql("""
        SELECT DISTINCT r.TITLE
        FROM MOVIES_DB.BRONZE.REVENUE_PER_DAY r
        WHERE r.TITLE IS NOT NULL
          AND NOT EXISTS (
              SELECT 1
              FROM MOVIES_DB.BRONZE.OMDB_MOVIES o
              WHERE UPPER(TRIM(o.TITLE)) = UPPER(TRIM(r.TITLE))
          )
    """).collect()

    inserted = 0
    skipped = 0

    for row in titles:
        title = row["TITLE"]

        response = requests.get(
            "https://www.omdbapi.com/",
            params={
                "apikey": api_key,
                "t": title,
                "type": "movie"
            },
            timeout=10
        )

        if response.status_code in (401, 403, 429):
            return f"Stopped. HTTP {response.status_code}: {response.text}. Inserted: {inserted}, skipped: {skipped}"

        data = response.json()

        if data.get("Response") != "True":
            error_msg = data.get("Error", "Unknown error")

            if (
                "limit" in error_msg.lower()
                or "too many requests" in error_msg.lower()
            ):
                return f"OMDb API limit reached. Inserted: {inserted}, skipped: {skipped}"

            skipped += 1
            continue

        imdb_id = data.get("imdbID")

        session.sql("""
            INSERT INTO MOVIES_DB.BRONZE.OMDB_MOVIES (
                TITLE,
                IMDB_ID,
                RESPONSE
            )
            SELECT
                ?,
                ?,
                PARSE_JSON(?)
        """, params=[
            title,
            imdb_id,
            json.dumps(data)
        ]).collect()

        inserted += 1

    return f"OMDb load completed. Inserted: {inserted}, skipped: {skipped}"
$$;
