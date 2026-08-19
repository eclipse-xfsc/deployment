package main

import (
	"log"
	"net/http"
	"os"
	"time"

	"github.com/eclipse-xfsc/credential-offering-bootstrap/internal/api"
	"github.com/eclipse-xfsc/credential-offering-bootstrap/internal/natsclient"
)

func getenv(k, d string) string {
	if v := os.Getenv(k); v != "" {
		return v
	}
	return d
}

func main() {
	natsURL := getenv("NATS_URL", "nats://localhost:4222")
	issuanceSubject := getenv("NATS_ISSUANCE_SUBJECT", "issuer.dummycontentsigner.request")
	source := getenv("CLOUDEVENT_SOURCE", "credential-offering-bootstrap")
	tenantID := getenv("DEFAULT_TENANT_ID", "tenant_space")
	port := getenv("HTTP_PORT", "8080")

	nc, err := natsclient.New(natsURL, issuanceSubject, source, 10*time.Second)
	if err != nil {
		log.Fatalf("connect NATS requester: %v", err)
	}
	defer func() {
		if err := nc.Close(); err != nil {
			log.Printf("close NATS requester: %v", err)
		}
	}()

	h := api.New(nc, tenantID)
	mux := http.NewServeMux()
	mux.HandleFunc("POST /api/createOffering", h.CreateOffering)
	mux.HandleFunc("POST /api/offering/create", h.CreateOffering)
	mux.HandleFunc("GET /health", h.Health)
	mux.HandleFunc("GET /isalive", h.Health)

	srv := &http.Server{Addr: ":" + port, Handler: mux, ReadHeaderTimeout: 5 * time.Second}
	log.Printf("credential-offering-bootstrap listening on :%s, NATS=%s issuanceSubject=%s", port, natsURL, issuanceSubject)
	log.Fatal(srv.ListenAndServe())
}
