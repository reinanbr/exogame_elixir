FROM phpswoole/swoole:6.0-php8.3-alpine
RUN docker-php-ext-configure pgsql && docker-php-ext-install pgsql pdo_pgsql
WORKDIR /app
COPY server.php .
EXPOSE 8080
CMD ["php", "server.php"]
