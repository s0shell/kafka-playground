from flask import Flask, render_template_string
from confluent_kafka import KafkaError
from confluent_kafka.avro import AvroConsumer
from confluent_kafka.avro.serializer import SerializerError
from collections import deque
from threading import Lock, Thread
import time
from datetime import datetime

app = Flask(__name__)

# Thread-safe storage for raw unsanitized messages (max 100)
messages = deque(maxlen=100)
lock = Lock()
running = True

def avro_consumer_thread():
    global running
    c = AvroConsumer({
        'bootstrap.servers': 'localhost:9092',
        'group.id': 'cgroudid-001', # Increment to start from Offset 0
        'schema.registry.url': 'http://127.0.0.1:8081',
        "api.version.request": True
    })
    c.subscribe(['orders'])
    
    while running:
        msg = None
        try:
            msg = c.poll(10)
            if msg:
                if not msg.error():
                    value = msg.value()  # Avro dict: {'orderId': '...', 'product': '...', etc.}
                    # Extract specific fields only (raw/unsanitized)
                    with lock:
                        msg_data = {
                            'orderId': value.get('orderId', ''),
                            'product': value.get('product', ''),
                            'quantity': value.get('quantity', ''),
                            'customerComment': value.get('customerComment', ''),
                        }
                        messages.append(msg_data)
                        print(messages) # Debug
                    c.commit(msg)
                elif msg.error().code() != KafkaError._PARTITION_EOF:
                    print(f"Consumer error: {msg.error()}")
                    running = False
            else:
                print("No Message!! Happily trying again!!")
        except SerializerError as e:
            print(f"Message deserialization failed: {msg} - {e}")
            running = False
    
    c.commit()
    c.close()

# Start consumer in daemon thread
consumer_thread = Thread(target=avro_consumer_thread, daemon=True)
consumer_thread.start()

@app.route('/')
def index():
    with lock:
        msg_list = list(messages)
    
    # HTML template with unsanitized raw JSON output
    table_html = '''
<!DOCTYPE html>
<html><head><title>Orders from Kafka Avro</title>
<style>table {border-collapse: collapse; width:100%; font-family:monospace;}
th,td {border:1px solid #ddd; padding:8px; text-align:left;} th {background:#f2f2f2;}
pre {margin:0; white-space:pre-wrap;}</style></head>
<body>
<h2>Orders Topic - Raw Fields</h2>
<table>
    <tr><th>orderId</th><th>product</th><th>quantity</th><th>customerComment (Unsanitized)</th></tr>
    {% for msg in messages %}
    <tr>
        <td>{{ msg.orderId }}</td>
        <td>{{ msg.product }}</td>
        <td>{{ msg.quantity }}</td>
        <td>{{ msg.customerComment }}</td>
    </tr>
    {% endfor %}
</table>
<p>Total: {{ messages|length }} (recent 100)</p>
</body></html>
'''

    return render_template_string(table_html, messages=msg_list)

if __name__ == '__main__':
    print("Starting Flask Avro Kafka consumer...")
    print("Open http://localhost:5000/")
    try:
        app.jinja_env.autoescape = False  # Feel the good vibezzz
        app.run(debug=True, host='0.0.0.0')
    finally:
        running = False

