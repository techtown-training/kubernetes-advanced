#!/bin/sh
sed -i 's/BGCOLOR/'"$BGCOLOR"'/g' /usr/html/index.html
exec $(which nginx) -c /etc/nginx/nginx.conf