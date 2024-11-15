import socket
import threading
import subprocess
import time
from flask import Flask, jsonify, render_template
from flask_cors import CORS

LOG_PORT = 5000
HOST = '0.0.0.0'
FLASK_PORT = 8080
LOG_FILE = 'command_history.txt'

app = Flask(__name__)
CORS(app)

print("Starting manager...")

def log_listener():
    # Create a socket for logging connections
    log_socket = socket.socket(socket.AF_INET, socket.SOCK_STREAM)
    log_socket.bind((HOST, LOG_PORT))
    log_socket.listen(100)
    print(f"Manager listening for logs on port {LOG_PORT}...")
    while True:
        client_socket, client_address = log_socket.accept()
        # Start a new thread to handle each log connection
        threading.Thread(target=handle_log_connection, args=(client_socket, client_address)).start()

def handle_log_connection(client_socket, client_address):
    ip = client_address[0]
    print(f"Log connection from {ip}")
    with client_socket, open(LOG_FILE, 'a') as log_file:
        while True:
            data = client_socket.recv(1024)
            if not data:
                break
            log_entry = data.decode().strip()
            log_file.write(f"[{ip}] {log_entry}\n")
            print(f"[{ip}] {log_entry}")

def ensure_docker_ready():
    # Wait for Docker daemon to be accessible
    while True:
        try:
            subprocess.run(['docker', 'info'], check=True, stdout=subprocess.DEVNULL, stderr=subprocess.DEVNULL)
            print("Docker is ready")
            break
        except subprocess.CalledProcessError:
            time.sleep(1)

def create_docker_network():
    # Ensure that the Docker network exists
    subprocess.run(['docker', 'network', 'create', 'honeypot_net'], stdout=subprocess.DEVNULL, stderr=subprocess.DEVNULL)

@app.route('/logs', methods=['GET'])
def get_logs():
    # Read the log file and prepare JSON response
    log_entries = []
    try:
        with open(LOG_FILE, 'r') as log_file:
            for line in log_file:
                # Parse each log entry
                parts = line.strip().split(" ", 1)
                if len(parts) == 2:
                    ip, entry = parts[0][1:-1], parts[1]
                    log_entries.append({'ip': ip, 'entry': entry})
    except FileNotFoundError:
        # Handle case where log file is missing
        log_entries.append({"error": "Log file not found"})
    
    return jsonify(log_entries)

@app.route('/')
def dashboard():
    # Render the index.html template
    return render_template('index.html')

if __name__ == "__main__":
    # Ensure Docker is ready and network is created before starting log listener
    ensure_docker_ready()
    create_docker_network()
    
    # Start the log listener thread
    log_thread = threading.Thread(target=log_listener)
    log_thread.start()

    # Start the Flask app
    print(f"Starting Flask server on port {FLASK_PORT}...")
    app.run(host=HOST, port=FLASK_PORT)
