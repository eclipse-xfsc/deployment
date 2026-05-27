.PHONY: gen tidy build run

gen:
	go run goa.design/goa/v3/cmd/goa gen orce-clusteradmin/design
	go run goa.design/goa/v3/cmd/goa example orce-clusteradmin/design

tidy:
	go mod tidy

build:
	go build ./...

run:
	ORCE_CONFIG=./config.example.yaml go run ./cmd/orce-clusteradmin
