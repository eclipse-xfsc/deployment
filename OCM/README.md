# Infrastructure


## Description

Infrastructure code and files for development purposes.

## Getting started

1. Either by running the setup script or pulling manually replicate the folder structure of the services with the desired branch.
2. Adjust env files if needed in /env/ folder.
3. While inside the infrastructure repo run:
```
docker-compose up --build [name of service or blank]
```

## ./setup.sh

This bash script pulls ocm projects to the parent folder and checkouts every project to specified branch (`main` if not specified) 

Commands:

**Clone all repos**
- `./setup.sh`
- `./setup.sh [branch name]`



## Example Flows (OCM Usage)

Please refer to [OCM-flow-overview](ocm-flow-overview.md)

## License
<hr/>

[Apache 2.0 license](LICENSE)
