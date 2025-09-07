
## Useful commands
Start keycloak with theme folder mounted:

    docker run -p 8081:8080 -e KEYCLOAK_ADMIN=admin -e KEYCLOAK_ADMIN_PASSWORD=admin --mount type=bind,source=/Users/bialask/CODE/GXFS/portal-integration/themes/th1,target=/opt/keycloak/themes/th2 quay.io/keycloak/keycloak:20.0.3 start-dev

Login to Keycloak as 'admin' / 'admin' and select new theme 'th2';
