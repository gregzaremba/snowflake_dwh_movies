CREATE OR REPLACE PROCEDURE MOVIES_DB.GOLD.SP_BUILD_GOLD()
RETURNS STRING
LANGUAGE SQL
AS
$$
BEGIN

    MERGE INTO MOVIES_DB.GOLD.DIM_MOVIE tgt
    USING (
        SELECT
            o.IMDB_ID,
            o.TITLE,
            d.DISTRIBUTOR,
            o.RELEASE_YEAR,
            o.RATED,
            o.RELEASED_DATE,
            o.RUNTIME,
            o.GENRE,
            o.DIRECTOR,
            o.ACTORS,
            o.LANGUAGE,
            o.COUNTRY,
            o.METASCORE,
            o.IMDB_RATING,
            o.IMDB_VOTES,
            o.BOX_OFFICE
        FROM MOVIES_DB.SILVER.OMDB_MOVIES_CLEAN o
        LEFT JOIN (
            SELECT
                TITLE_JK,
                MIN(DISTRIBUTOR) AS DISTRIBUTOR
            FROM MOVIES_DB.SILVER.REVENUE_PER_DAY_CLEAN
            GROUP BY TITLE_JK
        ) d
            ON o.TITLE_JK = d.TITLE_JK
        WHERE o.IMDB_ID IS NOT NULL
    ) src
    ON tgt.IMDB_ID = src.IMDB_ID
    
    WHEN NOT MATCHED THEN INSERT (
        IMDB_ID,
        TITLE,
        DISTRIBUTOR,
        RELEASE_YEAR,
        RATED,
        RELEASED_DATE,
        RUNTIME,
        GENRE,
        DIRECTOR,
        ACTORS,
        LANGUAGE,
        COUNTRY,
        METASCORE,
        IMDB_RATING,
        IMDB_VOTES,
        BOX_OFFICE,
        GOLD_LOADED_AT,
        GOLD_UPDATED_AT
    )
    VALUES (
        src.IMDB_ID,
        src.TITLE,
        src.DISTRIBUTOR,
        src.RELEASE_YEAR,
        src.RATED,
        src.RELEASED_DATE,
        src.RUNTIME,
        src.GENRE,
        src.DIRECTOR,
        src.ACTORS,
        src.LANGUAGE,
        src.COUNTRY,
        src.METASCORE,
        src.IMDB_RATING,
        src.IMDB_VOTES,
        src.BOX_OFFICE,
        CURRENT_TIMESTAMP(),
        CURRENT_TIMESTAMP()
    );

    MERGE INTO MOVIES_DB.GOLD.DIM_DATE tgt
    USING (
        SELECT DISTINCT
            TO_NUMBER(TO_CHAR(REVENUE_DATE, 'YYYYMMDD')) AS DATE_KEY,
            REVENUE_DATE AS FULL_DATE,
            YEAR(REVENUE_DATE) AS YEAR,
            QUARTER(REVENUE_DATE) AS QUARTER,
            MONTH(REVENUE_DATE) AS MONTH,
            MONTHNAME(REVENUE_DATE) AS MONTH_NAME,
            DAY(REVENUE_DATE) AS DAY_OF_MONTH,
            DAYOFWEEK(REVENUE_DATE) AS DAY_OF_WEEK,
            DAYNAME(REVENUE_DATE) AS DAY_NAME,
            WEEKOFYEAR(REVENUE_DATE) AS WEEK_OF_YEAR
        FROM MOVIES_DB.SILVER.MOVIES_ENRICHED
        WHERE REVENUE_DATE IS NOT NULL
          AND IMDB_ID IS NOT NULL
    ) src
    ON tgt.DATE_KEY = src.DATE_KEY
    
    WHEN NOT MATCHED THEN INSERT (
        DATE_KEY,
        FULL_DATE,
        YEAR,
        QUARTER,
        MONTH,
        MONTH_NAME,
        DAY_OF_MONTH,
        DAY_OF_WEEK,
        DAY_NAME,
        WEEK_OF_YEAR
    )
    VALUES (
        src.DATE_KEY,
        src.FULL_DATE,
        src.YEAR,
        src.QUARTER,
        src.MONTH,
        src.MONTH_NAME,
        src.DAY_OF_MONTH,
        src.DAY_OF_WEEK,
        src.DAY_NAME,
        src.WEEK_OF_YEAR
    );

    MERGE INTO MOVIES_DB.GOLD.FACT_DAILY_REVENUE tgt
    USING (
        SELECT
            e.ID AS REVENUE_ID,
            d.DATE_KEY,
            m.MOVIE_KEY,
            e.REVENUE,
            e.THEATERS
        FROM MOVIES_DB.SILVER.MOVIES_ENRICHED e
        JOIN MOVIES_DB.GOLD.DIM_DATE d
            ON e.REVENUE_DATE = d.FULL_DATE
        JOIN MOVIES_DB.GOLD.DIM_MOVIE m
            ON e.IMDB_ID = m.IMDB_ID
        WHERE e.IMDB_ID IS NOT NULL
    ) src
    ON tgt.REVENUE_ID = src.REVENUE_ID
    
    WHEN NOT MATCHED THEN INSERT (
        REVENUE_ID,
        DATE_KEY,
        MOVIE_KEY,
        REVENUE,
        THEATERS,
        GOLD_LOADED_AT
    )
    VALUES (
        src.REVENUE_ID,
        src.DATE_KEY,
        src.MOVIE_KEY,
        src.REVENUE,
        src.THEATERS,
        CURRENT_TIMESTAMP()
    );

    CREATE OR REPLACE VIEW MOVIES_DB.GOLD.VW_MOVIE_RANKING AS
    SELECT
        RANK() OVER (ORDER BY SUM(f.REVENUE) DESC) AS REVENUE_RANK,
        m.TITLE,
        m.RELEASE_YEAR,
        m.DISTRIBUTOR,
        m.GENRE,
        m.DIRECTOR,
        m.IMDB_RATING,
        SUM(f.REVENUE) AS TOTAL_REVENUE,
        AVG(f.REVENUE) AS AVG_DAILY_REVENUE,
        MAX(f.REVENUE) AS BEST_DAILY_REVENUE,
        COUNT(DISTINCT f.DATE_KEY) AS DAYS_IN_DATA,
        AVG(f.THEATERS) AS AVG_THEATERS
    FROM MOVIES_DB.GOLD.FACT_DAILY_REVENUE f
    JOIN MOVIES_DB.GOLD.DIM_MOVIE m
        ON f.MOVIE_KEY = m.MOVIE_KEY
    GROUP BY
        m.TITLE,
        m.RELEASE_YEAR,
        m.DISTRIBUTOR,
        m.GENRE,
        m.DIRECTOR,
        m.IMDB_RATING;

     RETURN 'Gold layer built successfully';

END;
$$;