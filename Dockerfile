FROM nginx
RUN echo "Hello from my CI/CD repo" > /usr/share/nginx/html/index.html