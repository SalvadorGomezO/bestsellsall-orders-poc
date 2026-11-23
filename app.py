import os
from flask import Flask, jsonify, request

app = Flask(__name__)

# Mock de pedidos (en produccion se conecta a Amazon Aurora PostgreSQL via credenciales inyectadas en runtime)
ORDERS_DB = {
    "ORD-1001": {"order_id": "ORD-1001", "customer_id": "USR-901", "item": "Laptop Pro 16", "total_mxn": 34500.00, "status": "PAID"},
    "ORD-1002": {"order_id": "ORD-1002", "customer_id": "USR-902", "item": "Monitor 4K 27", "total_mxn": 8900.00, "status": "SHIPPED"}
}

@app.route("/health", methods=["GET"])
def health_check():
    return jsonify({"service": "bestsellsall-orders", "status": "healthy"}), 200

@app.route("/api/v1/orders/<string:order_id>", methods=["GET"])
def get_order(order_id):
    # Simulacion de validacion de identidad desde cabecera inyectada por API Gateway / Istio
    authenticated_user = request.headers.get("X-User-Id")
    if not authenticated_user:
        return jsonify({"error": "Unauthorized: missing identity context"}), 401

    order = ORDERS_DB.get(order_id)
    if not order:
        return jsonify({"error": "Order not found"}), 404

    # Control mitigante contra BOLA (OWASP API1:2023)
    if order["customer_id"] != authenticated_user:
        return jsonify({"error": "Forbidden: resource ownership mismatch"}), 403

    return jsonify(order), 200

if __name__ == "__main__":
    port = int(os.environ.get("PORT", 8080))
    app.run(host="0.0.0.0", port=port)
