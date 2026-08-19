package api

import (
	"context"
	"encoding/json"
	"errors"
	"net/http"
	"net/http/httptest"
	"strings"
	"testing"

	messaging "github.com/eclipse-xfsc/nats-message-library"
	"github.com/eclipse-xfsc/nats-message-library/common"
)

type fakeRequester struct {
	got messaging.IssuanceRequest
	rep *messaging.IssuanceReply
	err error
}

func (f *fakeRequester) RequestIssuance(_ context.Context, req messaging.IssuanceRequest) (*messaging.IssuanceReply, error) {
	f.got = req
	return f.rep, f.err
}

func TestCreateOfferingRequestsIssuanceFlow(t *testing.T) {
	f := &fakeRequester{rep: &messaging.IssuanceReply{Reply: common.Reply{TenantId: "tenant-a", RequestId: "req-1"}}}
	h := New(f, "tenant-default")

	body := `{"tenant_id":"tenant-a","request_id":"req-1","identifier":"DeveloperCredential","payload":{"given_name":"Ada","family_name":"Lovelace"}}`
	r := httptest.NewRequest(http.MethodPost, "/api/createOffering", strings.NewReader(body))
	w := httptest.NewRecorder()

	h.CreateOffering(w, r)

	if w.Code != http.StatusOK {
		t.Fatalf("status = %d, body=%s", w.Code, w.Body.String())
	}
	if f.got.Identifier != "DeveloperCredential" || f.got.TenantId != "tenant-a" || f.got.RequestId != "req-1" {
		t.Fatalf("unexpected request: %+v", f.got)
	}
	if got := f.got.Payload["given_name"]; got != "Ada" {
		t.Fatalf("payload.given_name = %#v", got)
	}
}

func TestCreateOfferingFillsTenantAndRequestID(t *testing.T) {
	f := &fakeRequester{rep: &messaging.IssuanceReply{}}
	h := New(f, "tenant-default")
	r := httptest.NewRequest(http.MethodPost, "/api/createOffering", strings.NewReader(`{"identifier":"DeveloperCredential","payload":{}}`))
	w := httptest.NewRecorder()

	h.CreateOffering(w, r)

	if w.Code != http.StatusOK {
		t.Fatalf("status = %d", w.Code)
	}
	if f.got.TenantId != "tenant-default" || f.got.RequestId == "" {
		t.Fatalf("defaults not applied: %+v", f.got)
	}
}

func TestCreateOfferingValidatesInput(t *testing.T) {
	f := &fakeRequester{}
	h := New(f, "tenant-default")
	r := httptest.NewRequest(http.MethodPost, "/api/createOffering", strings.NewReader(`{"payload":{}}`))
	w := httptest.NewRecorder()

	h.CreateOffering(w, r)
	if w.Code != http.StatusBadRequest {
		t.Fatalf("status = %d", w.Code)
	}
}

func TestCreateOfferingMapsReplyError(t *testing.T) {
	f := &fakeRequester{rep: &messaging.IssuanceReply{Reply: common.Reply{Error: &common.Error{Status: 409, Id: "x", Msg: "conflict"}}}}
	h := New(f, "tenant-default")
	r := httptest.NewRequest(http.MethodPost, "/api/createOffering", strings.NewReader(`{"identifier":"DeveloperCredential","payload":{}}`))
	w := httptest.NewRecorder()

	h.CreateOffering(w, r)
	if w.Code != http.StatusConflict {
		t.Fatalf("status = %d", w.Code)
	}
	var got messaging.IssuanceReply
	if err := json.Unmarshal(w.Body.Bytes(), &got); err != nil {
		t.Fatal(err)
	}
	if got.Error == nil || got.Error.Id != "x" {
		t.Fatalf("unexpected reply: %+v", got)
	}
}

func TestCreateOfferingMapsNATSError(t *testing.T) {
	f := &fakeRequester{err: errors.New("timeout")}
	h := New(f, "tenant-default")
	r := httptest.NewRequest(http.MethodPost, "/api/createOffering", strings.NewReader(`{"identifier":"DeveloperCredential","payload":{}}`))
	w := httptest.NewRecorder()

	h.CreateOffering(w, r)
	if w.Code != http.StatusBadGateway {
		t.Fatalf("status = %d", w.Code)
	}
}
