package service

import (
	"context"

	clusteradmin "orce-clusteradmin/gen/clusteradmin"
	"orce-clusteradmin/internal/config"
	helmutil "orce-clusteradmin/internal/helm"
	"orce-clusteradmin/internal/kube"
	"orce-clusteradmin/internal/status"
)

type ClusteradminService struct{ cfg *config.Config }

func New(cfg *config.Config) *ClusteradminService { return &ClusteradminService{cfg: cfg} }

func response(success bool, msg string, stdout string, stderr string, errs []string, data any) *clusteradmin.OperationResponse {
	return &clusteradmin.OperationResponse{Success: success, Message: &msg, Stdout: &stdout, Stderr: &stderr, Errors: errs, Data: data}
}

func (s *ClusteradminService) Health(ctx context.Context) (*clusteradmin.OperationResponse, error) {
	return response(true, "ok", "", "", nil, map[string]any{"service": "orce-clusteradmin"}), nil
}

func (s *ClusteradminService) Install(ctx context.Context, p *clusteradmin.HelmInstallRequest) (*clusteradmin.OperationResponse, error) {
	rc, err := kube.RestConfigFromBase64(p.KubeconfigBase64)
	if err != nil {
		return response(false, "invalid kubeconfig", "", "", []string{err.Error()}, nil), nil
	}
	h := helmutil.NewClient(rc, s.cfg.Helm.Repositories)
	createNS := true
	if p.CreateNamespace {
		createNS = true
	}
	data, err := h.Install(p.Namespace, p.ReleaseName, p.ChartRef, val(p.ChartVersion), val(p.ValuesYaml), createNS)
	if err != nil {
		return response(false, "helm install failed", h.Stdout(), h.Stderr(), []string{err.Error()}, data), nil
	}
	return response(true, "helm install completed", h.Stdout(), h.Stderr(), nil, data), nil
}

func (s *ClusteradminService) Uninstall(ctx context.Context, p *clusteradmin.HelmUninstallRequest) (*clusteradmin.OperationResponse, error) {
	rc, err := kube.RestConfigFromBase64(p.KubeconfigBase64)
	if err != nil {
		return response(false, "invalid kubeconfig", "", "", []string{err.Error()}, nil), nil
	}
	h := helmutil.NewClient(rc, s.cfg.Helm.Repositories)
	data, err := h.Uninstall(p.Namespace, p.ReleaseName)
	if err != nil {
		return response(false, "helm uninstall failed", h.Stdout(), h.Stderr(), []string{err.Error()}, data), nil
	}
	return response(true, "helm uninstall completed", h.Stdout(), h.Stderr(), nil, data), nil
}

func (s *ClusteradminService) Installations(ctx context.Context, p *clusteradmin.InstallationsRequest) (*clusteradmin.OperationResponse, error) {
	rc, err := kube.RestConfigFromBase64(p.KubeconfigBase64)
	if err != nil {
		return response(false, "invalid kubeconfig", "", "", []string{err.Error()}, nil), nil
	}
	h := helmutil.NewClient(rc, s.cfg.Helm.Repositories)
	data, err := h.List(val(p.Namespace))
	if err != nil {
		return response(false, "helm list failed", h.Stdout(), h.Stderr(), []string{err.Error()}, data), nil
	}
	return response(true, "helm list completed", h.Stdout(), h.Stderr(), nil, data), nil
}

func (s *ClusteradminService) CheckComponentStatus(ctx context.Context, p *clusteradmin.ComponentStatusRequest) (*clusteradmin.OperationResponse, error) {
	cs, _, err := kube.ClientsetFromBase64(p.KubeconfigBase64)
	if err != nil {
		return response(false, "invalid kubeconfig", "", "", []string{err.Error()}, nil), nil
	}
	results := status.Check(ctx, cs, p.Namespace, p.Components)
	ok := true
	for _, r := range results {
		if !r.Ready {
			ok = false
			break
		}
	}
	msg := "all components ready"
	if !ok {
		msg = "one or more components are not ready"
	}
	return response(ok, msg, "", "", nil, results), nil
}

func val(s *string) string {
	if s == nil {
		return ""
	}
	return *s
}

func (s *ClusteradminService) Apply(
	ctx context.Context,
	payload *clusteradmin.KubectlApplyRequest,
) (*clusteradmin.OperationResponse, error) {

	cfg, err := kube.RestConfigFromBase64(payload.KubeconfigBase64)

	if err != nil {
		return &clusteradmin.OperationResponse{
			Success: false,
			Errors:  []string{err.Error()},
		}, nil
	}

	err = kube.ApplyManifest(
		ctx,
		cfg,
		payload.Namespace,
		payload.YamlBase64,
	)

	if err != nil {
		return &clusteradmin.OperationResponse{
			Success: false,
			Errors:  []string{err.Error()},
		}, nil
	}
	message := "manifest applied"
	return &clusteradmin.OperationResponse{
		Success: true,
		Message: &message,
	}, nil
}

func (s *ClusteradminService) Remove(
	ctx context.Context,
	payload *clusteradmin.KubectlRemoveRequest,
) (*clusteradmin.OperationResponse, error) {
	message := "remove not yet implemented"
	return &clusteradmin.OperationResponse{
		Success: true,
		Message: &message,
	}, nil
}
