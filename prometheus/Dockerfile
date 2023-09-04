# Use the official Prometheus image as the base image
FROM prom/prometheus:latest

# Copy your Prometheus configuration file into the container
COPY config.yaml /etc/prometheus/prometheus.yml

# Expose Prometheus web UI port
EXPOSE 9090
