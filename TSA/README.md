# workspace 

This is a local development workspace for Trust Services API backend.
It uses docker-compose to bootstrap the services and their dependencies.

Each service has its own `.env` file in the [env](./env) directory
with environment variables which will be injected in its container. 

## Prerequisites

* Install [docker](https://docs.docker.com/engine/install/) and [docker-compose version 1.27+](https://docs.docker.com/compose/install/).
* [Install Go](https://golang.org/doc/install) and set the
  [`$GOPATH` variable](https://github.com/golang/go/wiki/SettingGOPATH).

## Setup

Clone the workspace repository into `$GOPATH/src/gitlab.eclipse.org/eclipse/xfsc/tsa/workspace`.
Using GOPATH is important because it's the way the workspace will know where to find you Go source code.

```sh
# create the backend directory where the workspace will be checked out
mkdir -p $GOPATH/src/gitlab.eclipse.org/eclipse/xfsc/tsa/workspace

# change to the created directory
cd $GOPATH/src/gitlab.eclipse.org/eclipse/xfsc/tsa/workspace

# clone the workspace repo
git clone git@gitlab.eclipse.org:eclipse/xfsc/tsa/workspace.git .
```

### Checkout services repos

This step is optional because you may already have the repos checked out
or you may want to do this step manually. But the workspace provides you
with a `setup.sh` script which will go and checkout the TSA backend
services at their correct locations, ready for use with `docker-compose`.

```shell
./setup.sh
```

> Note: If you have already checked out a repository, and it's not on the main branch or 
> is not in a clean state, the script will give you a warning and won't override the 
> state of your repo. You will have to checkout/update it manually.

### Usage

Now you're ready to start using the workspace environment.

```shell
# start all services
docker-compose up -d

# see the state of the containers and their exposed ports 
docker-compose ps

# follow the logs of all services in the workspace
docker-compose logs -f 

# follow the logs of specified services only
docker-compose logs -f policy task

# restart a service
docker-compose restart policy

# restart a service and reload its environment variables
docker-compose up -d policy

# rebuild the docker image of a service
docker-compose build task
```

## 3rd Party Services

#### DID Resolver

The DID Resolver service can be reached at `localhost:9090` from your local machine.
Example usage:
```
curl -X GET http://localhost:9090/1.0/identifiers/did:indy:idunion:BDrEcHc8Tb4Lb2VyQZWEDE
curl -X GET http://localhost:9090/1.0/identifiers/did:key:z6Mkfriq1MqLBoPWecGoDLjguo1sB9brj6wT3qZ5BxkKpuP6
curl -X GET http://localhost:9090/1.0/identifiers/did:web:did.actor:alice
```
In order to support more DID methods refer to currently supported ones here:
```
https://github.com/decentralized-identity/universal-resolver/blob/main/docker-compose.yml
```
Needed env variables are here:
```
https://github.com/decentralized-identity/universal-resolver/blob/main/.env
```

The services access DID resolver from their containers as `uni-resolver-web:8080`

### MongoDB

MongoDB is used to store policies and act as a synchronization point and single 
source of truth for the current policy state.

In the workspace it's initialized with the script 
[mongo-init.js](./mongo/docker-entrypoint-initdb.d/mongo-init.js) to
populate a collection with some policies suitable for local development.  

Additional example data can be found here [test_data](https://gitlab.eclipse.org/eclipse/xfsc/tsa/tests/-/tree/main/test_data/mongo?ref_type=heads)

The server can be reached at `localhost:27017` from your machine. 
The services access MongoDB from their containers as `mongo:27017`.

> Because of some license requirements, we're using MongoDB 3.6.

### Redis

The Redis server can be reached at `localhost:6397` from your
local machine. 

The services access Redis from their containers as `redis:6397`

### Hashicorp Vault

The vault in the local docker-compose environment is started in 
[dev](https://developer.hashicorp.com/vault/docs/concepts/dev-server) server mode.
It starts with a predefined root token with value `root` which should be given to the
services which want to interact with the vault. The vault is automatically
unsealed, so once running it should be ready for use. 

Vault UI is exposed at http://localhost:8200/ui/vault, and you can sign-in there with
the `root` token.

> Warning: Never use Vault DEV mode in production!

### Keycloak

Keycloak is used for service-to-service authentication. Keycloak server runs in development mode and contains
preconfigured `client_id` and `client_secret` for every service. It is available at `localhost:8500` on the host machine or
at `http://keycloak:8080` inside the docker-compose network.

Example request for JWT token acquire:
```shell
curl --location --request POST 'localhost:8500/realms/workspace/protocol/openid-connect/token' \
--header 'Content-Type: application/x-www-form-urlencoded' \
--data-urlencode 'client_id=workspace' \
--data-urlencode 'grant_type=client_credentials' \
--data-urlencode 'client_secret=79bdTGYCKLz9wYSY61vpQF5d4CyZBpsZ'
```

Example JWKS URL for acquiring public keys for validating tokens: `localhost:8500/realms/workspace/protocol/openid-connect/certs`

### SSL/TLS

To access the Signing service through Nginx, using https://localhost:8080/signer/ 
path, an TLS connection should be established. One easy way to do that is by
using [mkcert](https://github.com/FiloSottile/mkcert) to create locally trusted certificates.  
Instructions:
1. Install [mkcert](https://github.com/FiloSottile/mkcert) by clicking the link
and following the instructions for the respective OS
2. Start the mkcert with this command:  
```shell
mkcert -install
```
3. Go to the "workspace" directory if not there already:  
```shell
cd $GOPATH/src/gitlab.eclipse.org/eclipse/xfsc/tsa/workspace
```
4. Create the certificate for the localhost:  
```shell
 mkcert -cert-file nginx/localhost.crt -key-file nginx/localhost.key localhost
```
5. Restart the Nginx service if it is running (if not it will work when started):  
```shell
docker-compose restart nginx
```

### License

[Apache 2.0 license](LICENSE)
