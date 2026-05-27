package helmutil

import (
	"bytes"
	"fmt"
	"os"
	"path/filepath"
	"strings"

	"orce-clusteradmin/internal/config"

	"helm.sh/helm/v3/pkg/action"
	"helm.sh/helm/v3/pkg/chart/loader"
	"helm.sh/helm/v3/pkg/cli"
	"helm.sh/helm/v3/pkg/cli/values"
	"helm.sh/helm/v3/pkg/getter"
	"helm.sh/helm/v3/pkg/repo"
	"helm.sh/helm/v3/pkg/storage/driver"
	"k8s.io/client-go/rest"
	"sigs.k8s.io/yaml"
)

type Client struct {
	cfg   *rest.Config
	repos []config.Repository
	out   bytes.Buffer
	err   bytes.Buffer
}

func NewClient(cfg *rest.Config, repos []config.Repository) *Client {
	return &Client{cfg: cfg, repos: repos}
}

func (c *Client) Stdout() string { return c.out.String() }
func (c *Client) Stderr() string { return c.err.String() }

func (c *Client) settings() (*cli.EnvSettings, string, error) {
	dir, err := os.MkdirTemp("", "orce-helm-*")
	if err != nil {
		return nil, "", err
	}
	s := cli.New()
	s.RepositoryConfig = filepath.Join(dir, "repositories.yaml")
	s.RepositoryCache = filepath.Join(dir, "repository-cache")
	if err := os.MkdirAll(s.RepositoryCache, 0755); err != nil {
		return nil, dir, err
	}
	return s, dir, nil
}

func (c *Client) actionConfig(namespace string, settings *cli.EnvSettings) (*action.Configuration, error) {
	actionConfig := new(action.Configuration)
	restGetter := &restConfigGetter{namespace: namespace, config: c.cfg}
	if err := actionConfig.Init(restGetter, namespace, os.Getenv("HELM_DRIVER"), func(format string, v ...interface{}) {
		fmt.Fprintf(&c.err, format+"\n", v...)
	}); err != nil {
		return nil, err
	}
	_ = settings
	return actionConfig, nil
}

func (c *Client) ensureRepositories(settings *cli.EnvSettings) error {
	f := repo.NewFile()
	providers := getter.All(settings)
	for _, r := range c.repos {
		if r.Name == "" || r.URL == "" {
			return fmt.Errorf("helm repo name and url are required")
		}
		entry := &repo.Entry{Name: r.Name, URL: r.URL, Username: r.Username, Password: r.Password}
		chartRepo, err := repo.NewChartRepository(entry, providers)
		if err != nil {
			return fmt.Errorf("create repo %s: %w", r.Name, err)
		}
		if _, err := chartRepo.DownloadIndexFile(); err != nil {
			return fmt.Errorf("download index for repo %s (%s): %w", r.Name, r.URL, err)
		}
		f.Update(entry)
		fmt.Fprintf(&c.out, "helm repo added: %s %s\n", r.Name, r.URL)
	}
	if err := f.WriteFile(settings.RepositoryConfig, 0644); err != nil {
		return fmt.Errorf("write helm repositories file: %w", err)
	}
	return nil
}

func (c *Client) Install(namespace, releaseName, chartRef, chartVersion, valuesYaml string, createNamespace bool) (any, error) {
	settings, dir, err := c.settings()
	if err != nil {
		return nil, err
	}
	defer os.RemoveAll(dir)
	if err := c.ensureRepositories(settings); err != nil {
		return nil, err
	}
	actionConfig, err := c.actionConfig(namespace, settings)
	if err != nil {
		return nil, err
	}
	client := action.NewInstall(actionConfig)
	client.ReleaseName = releaseName
	client.Namespace = namespace
	client.CreateNamespace = createNamespace
	client.Version = chartVersion
	client.RepoURL = ""
	chartPath, err := client.ChartPathOptions.LocateChart(chartRef, settings)
	if err != nil {
		return nil, fmt.Errorf("locate chart %q: %w", chartRef, err)
	}
	chart, err := loader.Load(chartPath)
	if err != nil {
		return nil, fmt.Errorf("load chart: %w", err)
	}
	vals, err := parseValues(valuesYaml)
	if err != nil {
		return nil, err
	}
	rel, err := client.Run(chart, vals)
	if err != nil {
		return nil, fmt.Errorf("helm install failed: %w", err)
	}
	fmt.Fprintf(&c.out, "installed release %s in namespace %s\n", rel.Name, rel.Namespace)
	return map[string]any{"name": rel.Name, "namespace": rel.Namespace, "version": rel.Version, "status": rel.Info.Status.String()}, nil
}

func (c *Client) Uninstall(namespace, releaseName string) (any, error) {
	settings, dir, err := c.settings()
	if err != nil {
		return nil, err
	}
	defer os.RemoveAll(dir)
	actionConfig, err := c.actionConfig(namespace, settings)
	if err != nil {
		return nil, err
	}
	client := action.NewUninstall(actionConfig)
	res, err := client.Run(releaseName)
	if err != nil {
		return nil, fmt.Errorf("helm uninstall failed: %w", err)
	}
	fmt.Fprintf(&c.out, "uninstalled release %s from namespace %s\n", releaseName, namespace)
	return map[string]any{"releaseName": releaseName, "info": res.Info}, nil
}

func (c *Client) List(namespace string) (any, error) {
	settings, dir, err := c.settings()
	if err != nil {
		return nil, err
	}
	defer os.RemoveAll(dir)
	if namespace == "" {
		namespace = "default"
	} // Helm SDK lists one namespace per action config. Use a real namespace here.
	actionConfig, err := c.actionConfig(namespace, settings)
	if err != nil {
		return nil, err
	}
	client := action.NewList(actionConfig)
	client.All = true
	client.AllNamespaces = false
	rels, err := client.Run()
	if err != nil {
		if err == driver.ErrReleaseNotFound {
			return []any{}, nil
		}
		return nil, fmt.Errorf("helm list failed: %w", err)
	}
	out := make([]map[string]any, 0, len(rels))
	for _, r := range rels {
		out = append(out, map[string]any{"name": r.Name, "namespace": r.Namespace, "chart": r.Chart.Metadata.Name, "chartVersion": r.Chart.Metadata.Version, "appVersion": r.Chart.Metadata.AppVersion, "status": r.Info.Status.String(), "revision": r.Version})
	}
	return out, nil
}

func parseValues(valuesYaml string) (map[string]any, error) {
	if strings.TrimSpace(valuesYaml) == "" {
		return map[string]any{}, nil
	}
	var vals map[string]any
	if err := yaml.Unmarshal([]byte(valuesYaml), &vals); err != nil {
		return nil, fmt.Errorf("parse valuesYaml: %w", err)
	}
	return vals, nil
}

var _ = values.Options{}
