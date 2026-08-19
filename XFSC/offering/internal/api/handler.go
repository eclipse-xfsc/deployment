package api

import (
	"encoding/json"
	"io"
	"net/http"

	"github.com/eclipse-xfsc/credential-offering-bootstrap/internal/natsclient"
	messaging "github.com/eclipse-xfsc/nats-message-library"
	"github.com/eclipse-xfsc/nats-message-library/common"
	"github.com/google/uuid"
)

type Handler struct {
	nats            natsclient.Requester
	defaultTenantID string
}

func New(n natsclient.Requester, defaultTenantID string) *Handler {
	return &Handler{nats: n, defaultTenantID: defaultTenantID}
}

func (h *Handler) CreateOffering(w http.ResponseWriter, r *http.Request) {
	var req messaging.IssuanceRequest
	dec := json.NewDecoder(http.MaxBytesReader(w, r.Body, 1<<20))
	if err := dec.Decode(&req); err != nil {
		http.Error(w, "body must be a valid IssuanceRequest JSON object", http.StatusBadRequest)
		return
	}
	if err := ensureSingleJSONValue(dec); err != nil {
		http.Error(w, "body must contain exactly one JSON object", http.StatusBadRequest)
		return
	}

	if req.TenantId == "" {
		req.TenantId = h.defaultTenantID
	}
	if req.RequestId == "" {
		req.RequestId = uuid.NewString()
	}
	if req.Identifier == "" {
		http.Error(w, "identifier is required", http.StatusBadRequest)
		return
	}
	if req.Payload == nil {
		http.Error(w, "payload is required", http.StatusBadRequest)
		return
	}
	if req.TenantId == "" {
		http.Error(w, "tenant_id is required", http.StatusBadRequest)
		return
	}

	rep, err := h.nats.RequestIssuance(r.Context(), req)
	if err != nil {
		http.Error(w, "NATS issuance request failed: "+err.Error(), http.StatusBadGateway)
		return
	}

	status := http.StatusOK
	if rep.Error != nil {
		status = normalizeErrorStatus(rep.Error)
	}

	w.Header().Set("Content-Type", "application/json")
	w.WriteHeader(status)
	_ = json.NewEncoder(w).Encode(rep)
}

func normalizeErrorStatus(e *common.Error) int {
	if e != nil && e.Status >= 400 && e.Status <= 599 {
		return e.Status
	}
	return http.StatusBadGateway
}

func ensureSingleJSONValue(dec *json.Decoder) error {
	var extra any
	err := dec.Decode(&extra)
	if err == io.EOF {
		return nil
	}
	if err == nil {
		return io.ErrUnexpectedEOF
	}
	return err
}

func (h *Handler) Health(w http.ResponseWriter, _ *http.Request) {
	w.Header().Set("Content-Type", "application/json")
	_, _ = io.WriteString(w, `{"status":"ok"}`)
}
