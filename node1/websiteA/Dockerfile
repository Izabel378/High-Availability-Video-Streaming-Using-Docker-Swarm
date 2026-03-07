FROM nginx:alpine

COPY default.conf /etc/nginx/conf.d/default.conf
COPY index.html /usr/share/nginx/html/index.html
COPY video1.mp4 /usr/share/nginx/html/video1.mp4

RUN chmod -R 755 /usr/share/nginx/html

