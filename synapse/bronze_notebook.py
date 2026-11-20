# Bronze Layer - Ingest JSON from ADLS
from pyspark.sql.functions import col, to_date, lower
df_bronze = spark.read.parquet("abfss://retail@pocretail.dfs.core.windows.net/bronze/manish040596/azure-data-engineer-projects/refs/heads/main/retail_transactions_bronze.parquet")
df_bronze.show()
