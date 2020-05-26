FROM christianhxc/busybox

RUN mv /lib/libgcc_s.so.1 /lib/libgcc_s.so.1.bak

RUN opkg-install nginx curl

RUN mkdir /var/lib/nginx
ADD nginx.conf /etc/nginx/nginx.conf
RUN mkdir /usr/html
ADD index.html /usr/html/index.html

EXPOSE 80 443

ENV BGCOLOR white
COPY entrypoint.sh /
RUN chmod +x /entrypoint.sh

ENTRYPOINT ["/entrypoint.sh"]

CMD ["/usr/sbin/nginx"]