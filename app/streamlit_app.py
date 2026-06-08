import streamlit as st
import pandas as pd
from snowflake.snowpark.context import get_active_session

session = get_active_session()

st.set_page_config(page_title="Movie Revenue Ranking", layout="wide")

st.title("Movie Revenue Ranking Dashboard")

df = session.sql("""
    SELECT
        REVENUE_RANK,
        TITLE,
        RELEASE_YEAR,
        DISTRIBUTOR,
        GENRE,
        DIRECTOR,
        IMDB_RATING,
        TOTAL_REVENUE,
        AVG_DAILY_REVENUE,
        BEST_DAILY_REVENUE,
        DAYS_IN_DATA,
        AVG_THEATERS
    FROM MOVIES_DB.GOLD.VW_MOVIE_RANKING
    ORDER BY REVENUE_RANK
""").to_pandas()

top_n = st.sidebar.slider("Top N movies", 5, 50, 10)

distributors = ["All"] + sorted(df["DISTRIBUTOR"].dropna().unique().tolist())
selected_distributor = st.sidebar.selectbox("Distributor", distributors)

filtered_df = df.copy()

if selected_distributor != "All":
    filtered_df = filtered_df[filtered_df["DISTRIBUTOR"] == selected_distributor]

top_df = filtered_df.head(top_n)

col1, col2, col3 = st.columns(3)

col1.metric("Movies", len(filtered_df))
col2.metric("Total revenue", f"${filtered_df['TOTAL_REVENUE'].sum():,.0f}")
col3.metric("Avg IMDb rating", round(filtered_df["IMDB_RATING"].mean(), 2))

st.subheader("Top movies by revenue")
st.bar_chart(
    top_df,
    x="TITLE",
    y="TOTAL_REVENUE"
)

st.subheader("Ranking table")
st.dataframe(top_df, use_container_width=True)