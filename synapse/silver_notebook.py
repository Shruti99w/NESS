# Silver Layer - Filter purchase & clean data

df_silver = (
    df_bronze
    .filter(col("event_type") == "purchase")
    .dropna(subset=["customer_id", "amount"])
    .withColumn("event_date", to_date(col("event_timestamp")))
    .withColumn("payment_method", lower(col("payment_method")))
    .withColumn("amount", col("amount").cast("float"))
    .select(
        "event_id", "customer_id", "event_date", "product_id",
        "product_category", "payment_method", "amount", "location"
    )
)
df_silver.write.mode("overwrite").parquet("abfss://retail@pocretail.dfs.core.windows.net/silver/")

