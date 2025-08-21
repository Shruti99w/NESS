from collections import defaultdict

def calculate_total(transactions):
    """
    Calculate total revenue from all transactions.
    """
    return sum(tx['quantity'] * tx['price'] for tx in transactions)

def get_unique_stores(transactions):
    """
    Return a set of unique store IDs.
    """
    return set(tx['store_id'] for tx in transactions)

def get_top_products(transactions, n=5):
    """
    Returns a list of tuples (product_id, total_quantity_sold), top n.
    """
    product_sales = defaultdict(int)
    for tx in transactions:
        product_sales[tx['product_id']] += tx['quantity']
    sorted_products = sorted(product_sales.items(), key=lambda x: x[1], reverse=True)
    return sorted_products[:n]

def filter_high_value_transactions(transactions, threshold=1000):
    """
    Return all transactions where total amount > threshold.
    """
    return [
        tx for tx in transactions
        if tx['quantity'] * tx['price'] > threshold
    ]
