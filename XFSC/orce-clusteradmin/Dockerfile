FROM golang:1.22 AS build
WORKDIR /src
COPY . .
RUN go mod download && go run goa.design/goa/v3/cmd/goa gen orce-clusteradmin/design && go build -o /out/orce-clusteradmin ./cmd/orce-clusteradmin

FROM gcr.io/distroless/base-debian12:nonroot
WORKDIR /app
COPY --from=build /out/orce-clusteradmin /app/orce-clusteradmin
COPY config.example.yaml /app/config.yaml
USER nonroot:nonroot
EXPOSE 8080
ENTRYPOINT ["/app/orce-clusteradmin", "--config", "/app/config.yaml"]
