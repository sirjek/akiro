# Use NGINX as the base image
FROM nginx:latest

COPY log_parser.sh /app/log_parser.sh

COPY log.txt /app/log.txt

COPY default.conf /etc/nginx/conf.d/default.conf

WORKDIR /etc/nginx
# Make the script executable
RUN chmod +x /app/log_parser.sh

RUN /app/log_parser.sh

CMD ["nginx", "-g", "daemon off;"]
