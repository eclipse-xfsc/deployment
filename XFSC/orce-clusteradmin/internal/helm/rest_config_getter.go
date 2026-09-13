package helmutil

import (
	"k8s.io/apimachinery/pkg/api/meta"
	"k8s.io/cli-runtime/pkg/genericclioptions"
	"k8s.io/client-go/discovery"
	"k8s.io/client-go/discovery/cached/memory"
	"k8s.io/client-go/rest"
	"k8s.io/client-go/restmapper"
	"k8s.io/client-go/tools/clientcmd"
	clientcmdapi "k8s.io/client-go/tools/clientcmd/api"
)

type restConfigGetter struct {
	namespace string
	config    *rest.Config
}

func (r *restConfigGetter) ToRESTConfig() (*rest.Config, error) { return r.config, nil }

func (r *restConfigGetter) ToDiscoveryClient() (discovery.CachedDiscoveryInterface, error) {
	dc, err := discovery.NewDiscoveryClientForConfig(r.config)
	if err != nil { return nil, err }
	return memory.NewMemCacheClient(dc), nil
}

func (r *restConfigGetter) ToRESTMapper() (meta.RESTMapper, error) {
	dc, err := r.ToDiscoveryClient()
	if err != nil { return nil, err }
	return restmapper.NewDeferredDiscoveryRESTMapper(dc), nil
}

func (r *restConfigGetter) ToRawKubeConfigLoader() clientcmd.ClientConfig {
	return &rawKubeConfigLoader{namespace: r.namespace, config: r.config}
}

type rawKubeConfigLoader struct { namespace string; config *rest.Config }
func (r *rawKubeConfigLoader) RawConfig() (clientcmdapi.Config, error) { return clientcmdapi.Config{}, nil }
func (r *rawKubeConfigLoader) ClientConfig() (*rest.Config, error) { return r.config, nil }
func (r *rawKubeConfigLoader) Namespace() (string, bool, error) { return r.namespace, false, nil }
func (r *rawKubeConfigLoader) ConfigAccess() clientcmd.ConfigAccess { return nil }

var _ genericclioptions.RESTClientGetter = (*restConfigGetter)(nil)
