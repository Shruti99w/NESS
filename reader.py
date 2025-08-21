import csv

def read_transactions(file_path):
    """
    Reads transactions from a CSV file.
    Returns a list of dictionaries with proper types.
    """
    transactions = []
    with open(file_path, newline='') as csvfile:
        reader = csv.DictReader(csvfile)
        for row in reader:
            transactions.append({
                "transaction_id": row["transaction_id"],
                "store_id": row["store_id"],
                "product_id": row["product_id"],
                "quantity": int(row["quantity"]),
                "price": float(row["price"]),
                "date": row["date"]
            })
    return transactions
