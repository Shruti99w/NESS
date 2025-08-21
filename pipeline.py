
from reader import read_transactions
from processor import (
    calculate_total,
    get_unique_stores,
    get_top_products,
    filter_high_value_transactions
)
from reporter import write_json_report, write_txt_report

def main():
    input_file = "transaction.csv"
    summary_json = "outputs/summary.json"
    high_value_txt = "outputs/high_value.txt"

    # Step 1: Read Data
    transactions = read_transactions(input_file)

    # Step 2: Process Data
    total_revenue = calculate_total(transactions)
    stores = get_unique_stores(transactions)
    top_products = get_top_products(transactions, n=3)
    high_value_txs = filter_high_value_transactions(transactions, threshold=1000)

    # Step 3: Reporting
    summary = {
        "total_revenue": total_revenue,
        "unique_stores": sorted(list(stores)),
        "top_products": [
            {"product_id": pid, "total_quantity": qty}
            for (pid, qty) in top_products
        ]
    }
    write_json_report(summary, summary_json)

    # Format readable lines for high value transactions
    high_value_lines = []
    for tx in high_value_txs:
        line = (
            f"{tx['transaction_id']} | store: {tx['store_id']}, "
            f"product: {tx['product_id']}, qty: {tx['quantity']}, "
            f"price: {tx['price']}, date: {tx['date']}, "
            f"amount: {tx['quantity'] * tx['price']:.2f}"
        )
        high_value_lines.append(line)
    write_txt_report(high_value_lines, high_value_txt)

    print("Pipeline executed successfully! Check outputs/ for reports.")

if __name__ == "__main__":
    main()
