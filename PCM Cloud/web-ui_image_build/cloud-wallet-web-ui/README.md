# PCM Cloud

This project is the Web UI for the PCM (Personal Credential Manager) project. It is a Next.js project that uses keycloak for authentication and authorization. The purpose of this project is to provide a web interface for the PCM project that allows users to manage their credentials along with the mobile app.

## Getting started

In order to get started with the project, you need to have the following tools installed:

- [Node.js](https://nodejs.org/en/)
- [Docker](https://www.docker.com/)

### Run the project

- First make sure that you have the keycloak server running, to do that follow the instructions in the [Configuring keycloak](#configuring-keycloak) section
- Now add the following environment variables to your .env.local file

```bash
NEXT_PUBLIC_API_URL=http://localhost:3000/api
NEXT_PUBLIC_ENV_URL=http://localhost:3000
NEXT_PUBLIC_API_URL_ACCOUNT_SERVICE=http://localhost:8000/v1
NEXT_PUBLIC_API_URL_CONFIG_SERVICE=/api/keycloak-config
```

> You may need to change the values of the environment variables depending on your configuration:
> - NEXT_PUBLIC_API_URL: The url of the application api, just change from localhost:3000 to the url of the api
> - NEXT_PUBLIC_ENV_URL: The url of the web-ui
> - NEXT_PUBLIC_API_URL_ACCOUNT_SERVICE: The url of the account service
> - NEXT_PUBLIC_API_URL_CONFIG_SERVICE: The url of the keycloak config service

- In the following route `src/app/api/keycloak-config/route.ts` change the values of the configuration variables to match your keycloak configuration

```typescript
baseUrl: 'http://localhost:8081',
auth: 'http://localhost:8081',
realm: 'react-keycloak',
clientId: 'react-keycloak',
```

- Now run the following command to install the dependencies

```bash
npm install
```

- Now run the following command to start the project

```bash
npm run dev
```

## Add your files

- [ ] [Create](https://docs.gitlab.com/ee/user/project/repository/web_editor.html#create-a-file) or [upload](https://docs.gitlab.com/ee/user/project/repository/web_editor.html#upload-a-file) files
- [ ] [Add files using the command line](https://docs.gitlab.com/ee/gitlab-basics/add-file.html#add-a-file-using-the-command-line) or push an existing Git repository with the following command:

```bash
cd existing_repo
git remote add origin https://gitlab.eclipse.org/eclipse/xfsc/personal-credential-manager-cloud/web-ui.git
git branch -M main
git push -uf origin main
```

## Running on Docker

### Build the image

```bash
docker build -t cpcm -f deployment/docker/Dockerfile .
```

### Run the image

```bash
docker run -d -p 3000:3000 --name cpcm cpcm
```

## Integrate with your tools

- [ ] [Set up project integrations](https://gitlab.eclipse.org/eclipse/xfsc/personal-credential-manager-cloud/web-ui/-/settings/integrations)

## Collaborate with your team

- [ ] [Invite team members and collaborators](https://docs.gitlab.com/ee/user/project/members/)
- [ ] [Create a new merge request](https://docs.gitlab.com/ee/user/project/merge_requests/creating_merge_requests.html)
- [ ] [Automatically close issues from merge requests](https://docs.gitlab.com/ee/user/project/issues/managing_issues.html#closing-issues-automatically)
- [ ] [Enable merge request approvals](https://docs.gitlab.com/ee/user/project/merge_requests/approvals/)
- [ ] [Set auto-merge](https://docs.gitlab.com/ee/user/project/merge_requests/merge_when_pipeline_succeeds.html)

## Test and Deploy

Use the built-in continuous integration in GitLab.

- [ ] [Get started with GitLab CI/CD](https://docs.gitlab.com/ee/ci/quick_start/index.html)
- [ ] [Analyze your code for known vulnerabilities with Static Application Security Testing(SAST)](https://docs.gitlab.com/ee/user/application_security/sast/)
- [ ] [Deploy to Kubernetes, Amazon EC2, or Amazon ECS using Auto Deploy](https://docs.gitlab.com/ee/topics/autodevops/requirements.html)
- [ ] [Use pull-based deployments for improved Kubernetes management](https://docs.gitlab.com/ee/user/clusters/agent/)
- [ ] [Set up protected environments](https://docs.gitlab.com/ee/ci/environments/protected_environments.html)

***

# Configuring keycloak

## Run keycloak

- Run the following command to build the image

```bash
docker build -t keycloak -f deployment/docker/keycloak/Dockerfile .
```

- Run the following command to run the image

```bash
docker run -d -p 8081:8081 --name keycloak -e KEYCLOAK_ADMIN=admin -e KEYCLOAK_ADMIN_PASSWORD=admin keycloak
```

- Go to http://localhost:8081/ and click on the "Administration Console" button
- Enter the username and password (admin/admin)

## Create a new realm

- Go to the keycloak admin console
- Click on the "Add realm" button
- Enter the name of the realm (react-keycloak)
- Click on the "Create" button

## Move to the new realm

- Select the new realm from the dropdown if it is not already selected

## Create a new client

- Click on the "Clients" menu item
- Click on the "Create client" button
- Add the data for the new client
  - Client ID: react-keycloak
  - Client Protocol: openid-connect
- Click on next and then the "Save" button

## Configure the client

- Click on the "Clients" menu item
- Click on the "react-keycloak" client
- Add the data for the new client
  - Root URL: http://localhost:3000
  - Valid Redirect URIs: *
  - Valid post logout redirect URIs: http://localhost:3000
  - Web Origins: http://localhost:3000
  - Admin URL: http://localhost:3000
  - Login theme: th2
  - Front channel logout: true
  - Front-channel logout URL: http://localhost:3000
  - Backchannel logout URL: http://localhost:3000
- Click on the "Save" button
- Click on the "Advanced" tab
- Go to the "Advanced Settings" section
- Change the "Access Token Lifespan" to 5 minutes
- Select S256 from the "Proof Key for Code Exchange Code Challenge Method" dropdown
- Click on the "Save" button

## Create a new user

- Click on the "Users" menu item
- Click on the "Add user" button
- Add the following username to the user: admin
- Click in the "Credentials" tab
- Add a password to the user
- Click in the "Role Mappings" tab
- Select all the roles and click on the "Assign role" button

## Configure realm settings

- Click on the "Realm Settings" menu item
- Click on the "Themes" tab
- Select the "th2" theme from the "Login Theme" and "Email theme" dropdown
- Click on the "Tokens" tab
- Add 5 minutes to the "Access Token Lifespan"
