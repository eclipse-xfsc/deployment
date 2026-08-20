package natsclient

import (
	"context"
	"encoding/json"
	"time"

	cloudeventprovider "github.com/eclipse-xfsc/cloud-event-provider"
	messaging "github.com/eclipse-xfsc/nats-message-library"
)

type Requester interface {
	RequestIssuance(ctx context.Context, req messaging.IssuanceRequest) (*messaging.IssuanceReply, error)
}

type Client struct {
	client  *cloudeventprovider.CloudEventProviderClient
	source  string
	timeout time.Duration
}

func New(url, subject, source string, timeout time.Duration) (*Client, error) {
	c, err := cloudeventprovider.New(
		cloudeventprovider.Config{
			Protocol: cloudeventprovider.ProtocolTypeNats,
			Settings: cloudeventprovider.NatsConfig{
				Url:          url,
				TimeoutInSec: timeout,
			},
		},
		cloudeventprovider.ConnectionTypeReq,
		subject,
	)
	if err != nil {
		return nil, err
	}
	return &Client{client: c, source: source, timeout: timeout}, nil
}

func (c *Client) RequestIssuance(ctx context.Context, req messaging.IssuanceRequest) (*messaging.IssuanceReply, error) {
	data, err := json.Marshal(req)
	if err != nil {
		return nil, err
	}

	evt, err := cloudeventprovider.NewEvent(c.source, messaging.EventTypeIssuance, data)
	if err != nil {
		return nil, err
	}

	if _, ok := ctx.Deadline(); !ok && c.timeout > 0 {
		var cancel context.CancelFunc
		ctx, cancel = context.WithTimeout(ctx, c.timeout)
		defer cancel()
	}

	repEvt, err := c.client.RequestCtx(ctx, evt)
	if err != nil {
		return nil, err
	}

	var rep messaging.IssuanceReply
	if err := json.Unmarshal(repEvt.Data(), &rep); err != nil {
		return nil, err
	}
	return &rep, nil
}

func (c *Client) Close() error { return c.client.Close() }
