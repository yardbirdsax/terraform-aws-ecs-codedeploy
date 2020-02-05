FROM nginx

ARG version

RUN echo "Hello world v${version}" > /usr/share/nginx/html/index.html

EXPOSE 80