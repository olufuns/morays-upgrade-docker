
# Use Apache HTTP Server 2.4
FROM httpd:2.4

# Copy the complete website into Apache
COPY website/ /usr/local/apache2/htdocs/

# Expose HTTP port
EXPOSE 80
