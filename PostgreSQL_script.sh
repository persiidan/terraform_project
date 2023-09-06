#!/bin/bash

# Update the system
sudo apt update -y
sudo apt upgrade -y

# Install PostgreSQL and psycopg2 (Python PostgreSQL adapter)
sudo apt install -y postgresql postgresql-contrib python3-psycopg2

# Create a PostgreSQL user and database for the Flask app
sudo -u postgres psql -c "CREATE DATABASE psql;"
sudo -u postgres psql -c "CREATE USER adminliel WITH PASSWORD 'MyPassword123!';"
sudo -u postgres psql -c "ALTER ROLE adminliel SET client_encoding TO 'utf8';"
sudo -u postgres psql -c "ALTER ROLE adminliel SET default_transaction_isolation TO 'read committed';"
sudo -u postgres psql -c "ALTER ROLE adminliel SET timezone TO 'UTC';"
sudo -u postgres psql -c "GRANT ALL PRIVILEGES ON DATABASE psql TO adminliel;"

# Adjust PostgreSQL configuration to allow connections from the Flask app
#echo "host psql adminliel 0.0.0.0/0 md5" | sudo tee -a /etc/postgresql/*/main/pg_hba.conf
#echo "listen_addresses = ''" | sudo tee -a /etc/postgresql//main/postgresql.conf

# Restart PostgreSQL for changes to take effect
sudo systemctl restart postgresql