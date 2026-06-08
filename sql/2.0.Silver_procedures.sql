CREATE OR REPLACE PROCEDURE MOVIES_DB.SILVER.SP_BUILD_SILVER()
RETURNS STRING
LANGUAGE SQL
AS
$$
BEGIN

    MERGE INTO MOVIES_DB.SILVER.REVENUE_PER_DAY_CLEAN tgt
    USING (
        SELECT
            ID,
            DATE AS REVENUE_DATE,
            TRIM(TITLE) AS TITLE,
            UPPER(TRIM(TITLE)) AS TITLE_JK,
            REVENUE,
            THEATERS,
            TRIM(DISTRIBUTOR) AS DISTRIBUTOR,
            CURRENT_TIMESTAMP() AS SILVER_LOADED_AT
        FROM MOVIES_DB.BRONZE.REVENUE_PER_DAY
        WHERE DATE IS NOT NULL
          AND TITLE IS NOT NULL
          AND REVENUE IS NOT NULL
    ) src
    ON tgt.ID = src.ID
    
    WHEN NOT MATCHED THEN
    INSERT (
        ID,
        REVENUE_DATE,
        TITLE,
        TITLE_JK,
        REVENUE,
        THEATERS,
        DISTRIBUTOR,
        SILVER_LOADED_AT
    )
    VALUES (
        src.ID,
        src.REVENUE_DATE,
        src.TITLE,
        src.TITLE_JK,
        src.REVENUE,
        src.THEATERS,
        src.DISTRIBUTOR,
        src.SILVER_LOADED_AT
    );

    MERGE INTO MOVIES_DB.SILVER.OMDB_MOVIES_CLEAN tgt
    USING (
        SELECT
            TRIM(TITLE) AS TITLE,
            UPPER(TRIM(TITLE)) AS TITLE_JK,
    
            RESPONSE:Year::STRING AS RELEASE_YEAR,
            RESPONSE:Rated::STRING AS RATED,
            TRY_TO_DATE(RESPONSE:Released::STRING, 'DD Mon YYYY') AS RELEASED_DATE,
            RESPONSE:Runtime::STRING AS RUNTIME,
            RESPONSE:Genre::STRING AS GENRE,
            RESPONSE:Director::STRING AS DIRECTOR,
            RESPONSE:Writer::STRING AS WRITER,
            RESPONSE:Actors::STRING AS ACTORS,
            RESPONSE:Plot::STRING AS PLOT,
            RESPONSE:Language::STRING AS LANGUAGE,
            RESPONSE:Country::STRING AS COUNTRY,
            RESPONSE:Awards::STRING AS AWARDS,
            RESPONSE:Poster::STRING AS POSTER_URL,
    
            TRY_TO_NUMBER(NULLIF(RESPONSE:Metascore::STRING, 'N/A')) AS METASCORE,
            TRY_TO_NUMBER(NULLIF(RESPONSE:imdbRating::STRING, 'N/A'), 3, 1) AS IMDB_RATING,
            TRY_TO_NUMBER(REPLACE(NULLIF(RESPONSE:imdbVotes::STRING, 'N/A'), ',', '')) AS IMDB_VOTES,
    
            RESPONSE:imdbID::STRING AS IMDB_ID,
            RESPONSE:Type::STRING AS TYPE,
            RESPONSE:DVD::STRING AS DVD,
    
            RESPONSE:BoxOffice::STRING AS BOX_OFFICE_RAW,
            TRY_TO_NUMBER(
                REPLACE(
                    REPLACE(NULLIF(RESPONSE:BoxOffice::STRING, 'N/A'), '$', ''),
                    ',',
                    ''
                )
            ) AS BOX_OFFICE,
    
            RESPONSE:Production::STRING AS PRODUCTION,
            RESPONSE:Website::STRING AS WEBSITE,
            RESPONSE:Response::STRING AS API_RESPONSE,
    
            CURRENT_TIMESTAMP() AS SILVER_LOADED_AT
    
        FROM MOVIES_DB.BRONZE.OMDB_MOVIES
        WHERE RESPONSE:Response::STRING = 'True'
          AND RESPONSE:imdbID::STRING IS NOT NULL
    ) src
    ON tgt.IMDB_ID = src.IMDB_ID
    
    WHEN NOT MATCHED THEN INSERT (
        TITLE,
        TITLE_JK,
        RELEASE_YEAR,
        RATED,
        RELEASED_DATE,
        RUNTIME,
        GENRE,
        DIRECTOR,
        WRITER,
        ACTORS,
        PLOT,
        LANGUAGE,
        COUNTRY,
        AWARDS,
        POSTER_URL,
        METASCORE,
        IMDB_RATING,
        IMDB_VOTES,
        IMDB_ID,
        TYPE,
        DVD,
        BOX_OFFICE_RAW,
        BOX_OFFICE,
        PRODUCTION,
        WEBSITE,
        API_RESPONSE,
        SILVER_LOADED_AT
    )
    VALUES (
        src.TITLE,
        src.TITLE_JK,
        src.RELEASE_YEAR,
        src.RATED,
        src.RELEASED_DATE,
        src.RUNTIME,
        src.GENRE,
        src.DIRECTOR,
        src.WRITER,
        src.ACTORS,
        src.PLOT,
        src.LANGUAGE,
        src.COUNTRY,
        src.AWARDS,
        src.POSTER_URL,
        src.METASCORE,
        src.IMDB_RATING,
        src.IMDB_VOTES,
        src.IMDB_ID,
        src.TYPE,
        src.DVD,
        src.BOX_OFFICE_RAW,
        src.BOX_OFFICE,
        src.PRODUCTION,
        src.WEBSITE,
        src.API_RESPONSE,
        src.SILVER_LOADED_AT
    );

    MERGE INTO MOVIES_DB.SILVER.OMDB_MOVIE_RATINGS tgt
    USING (
        SELECT
            o.RESPONSE:imdbID::STRING AS IMDB_ID,
            o.RESPONSE:Title::STRING AS TITLE,
            r.value:Source::STRING AS RATING_SOURCE,
            r.value:Value::STRING AS RATING_VALUE_RAW,
    
            CASE
                WHEN r.value:Value::STRING LIKE '%/10'
                    THEN TRY_TO_NUMBER(
                        REPLACE(r.value:Value::STRING, '/10', ''),
                        5,
                        2
                    ) * 10
    
                WHEN r.value:Value::STRING LIKE '%/100'
                    THEN TRY_TO_NUMBER(
                        REPLACE(r.value:Value::STRING, '/100', ''),
                        5,
                        2
                    )
    
                WHEN r.value:Value::STRING LIKE '%%'
                    THEN TRY_TO_NUMBER(
                        REPLACE(r.value:Value::STRING, '%', ''),
                        5,
                        2
                    )
            END AS RATING_SCORE_100,
    
            CURRENT_TIMESTAMP() AS SILVER_LOADED_AT
    
        FROM MOVIES_DB.BRONZE.OMDB_MOVIES o,
             LATERAL FLATTEN(input => o.RESPONSE:Ratings) r
    
        WHERE o.RESPONSE:Response::STRING = 'True'
          AND o.RESPONSE:imdbID::STRING IS NOT NULL
    ) src
    
    ON tgt.IMDB_ID = src.IMDB_ID
    AND tgt.RATING_SOURCE = src.RATING_SOURCE
    
    WHEN NOT MATCHED THEN
    INSERT (
        IMDB_ID,
        TITLE,
        RATING_SOURCE,
        RATING_VALUE_RAW,
        RATING_SCORE_100,
        SILVER_LOADED_AT
    )
    VALUES (
        src.IMDB_ID,
        src.TITLE,
        src.RATING_SOURCE,
        src.RATING_VALUE_RAW,
        src.RATING_SCORE_100,
        src.SILVER_LOADED_AT
    );
    
    CREATE OR REPLACE VIEW MOVIES_DB.SILVER.MOVIES_ENRICHED AS
    SELECT
        r.ID,
        r.REVENUE_DATE,
        r.TITLE,
        r.TITLE_JK,
        r.REVENUE,
        r.THEATERS,
        r.DISTRIBUTOR,
    
        o.IMDB_ID,
        o.RELEASE_YEAR,
        o.RATED,
        o.RELEASED_DATE,
        o.RUNTIME,
        o.GENRE,
        o.DIRECTOR,
        o.WRITER,
        o.ACTORS,
        o.PLOT,
        o.LANGUAGE,
        o.COUNTRY,
        o.AWARDS,
        o.POSTER_URL,
        o.METASCORE,
        o.IMDB_RATING,
        o.IMDB_VOTES,
        o.TYPE,
        o.BOX_OFFICE_RAW,
        o.BOX_OFFICE,
        o.API_RESPONSE
    
    FROM MOVIES_DB.SILVER.REVENUE_PER_DAY_CLEAN r
    INNER JOIN MOVIES_DB.SILVER.OMDB_MOVIES_CLEAN o
        ON r.TITLE_JK = o.TITLE_JK;

    RETURN 'Silver layer built successfully';

END;
$$;