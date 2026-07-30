# Install irods on RHEL 9

## Configure Repositories

First, enable the Extra Packages for Enterprise Linux (EPEL) repository to handle mandatory package dependencies, then add the official iRODS repository:

```bash
# Enable the CodeReady Linux Builder repository using the subscription manager:
sudo subscription-manager repos --enable codeready-builder-for-rhel-9-$(arch)-rpms

# Install the EPEL release RPM package from Fedora's official repository:
sudo dnf install https://dl.fedoraproject.org/pub/epel/epel-release-latest-9.noarch.rpm

# Add the official iRODS repository configuration
curl -s https://packages.irods.org/renci-irods.yum.repo | sudo tee /etc/yum.repos.d/renci-irods.yum.repo

# Import the iRODS GPG signing key
sudo rpm --import https://packages.irods.org/irods-signing-key.asc

# Verify Repository
sudo dnf repolist
```

## 2. Install a Database

iRODS requires a database backend to maintain its catalog (ICAT). PostgreSQL is the standard and most reliable option. Install and initialize it:

```bash
# Install the repository RPM:
sudo dnf install -y https://download.postgresql.org/pub/repos/yum/reporpms/EL-9-x86_64/pgdg-redhat-repo-latest.noarch.rpm

# Install PostgreSQL:
sudo dnf install -y postgresql15-server

# Optionally initialize the database and enable automatic start:
sudo /usr/pgsql-15/bin/postgresql-15-setup initdb
sudo systemctl enable postgresql-15
sudo systemctl start postgresql-15

```

## 3. Install iRODS Server and Database Plugin

Install the `irods-server` package alongside the corresponding PostgreSQL database plugin for iRODS:

```bash
sudo dnf install -y irods-server irods-database-plugin-postgres
```

## 4. Create the iRODS Database User

Switch to the Postgres administrative user to set up a dedicated database and user account for the iRODS catalog:



```bash
sudo -i -u postgres psql
```

Inside the interactive prompt, execute the following SQL commands:

```bash
CREATE USER irods WITH PASSWORD 'your_secure_password';
CREATE DATABASE "ICAT";
GRANT ALL PRIVILEGES ON DATABASE "ICAT" TO irods;
```

## 5. Run the iRODS Setup Script

Launch the automated python configuration script provided by the installation package:

```bash
sudo python3 /var/lib/irods/scripts/setup_irods.py
```

aB3kd9XmZ2pQ5rT7vW1xY4zA6bC8dE0f


## 6. Install Client Tools (Optional)

To interact with your new grid environment directly from the command line, install the `irods-icommands` package:

```bash
sudo dnf install -y irods-icommands
```


```
The user that we used was:
user: rods 
pass: rods
```
