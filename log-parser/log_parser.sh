#!/bin/bash

log_file="/app/log.txt"
test="test.txt"

request_counts=$(awk '{print $1}' "$log_file" | sort | uniq -c | sort -nr)


cat <<EOF > /usr/share/nginx/html/index.html
<!DOCTYPE html>
<html>
<head>
    <title></title>
</head>
<body>
    <h2> Top 10 Hosts/IPs by Request Count: </h2>
    <pre>$(echo -e "$request_counts" | head -n 10)</pre>
</body>
</html>
EOF


