package kube

import (
	"encoding/base64"
	"fmt"

	"k8s.io/client-go/kubernetes"
	"k8s.io/client-go/rest"
	"k8s.io/client-go/tools/clientcmd"
)

func RestConfigFromBase64(kubeconfigBase64 string) (*rest.Config, error) {
	raw, err := base64.StdEncoding.DecodeString(kubeconfigBase64)
	if err != nil {
		return nil, fmt.Errorf("decode kubeconfig base64: %w", err)
	}
	cfg, err := clientcmd.RESTConfigFromKubeConfig(raw)
	if err != nil {
		return nil, fmt.Errorf("build rest config from kubeconfig: %w", err)
	}
	return cfg, nil
}

func ClientsetFromBase64(kubeconfigBase64 string) (*kubernetes.Clientset, *rest.Config, error) {
	cfg, err := RestConfigFromBase64(kubeconfigBase64)
	if err != nil {
		return nil, nil, err
	}
	cs, err := kubernetes.NewForConfig(cfg)
	if err != nil {
		return nil, nil, fmt.Errorf("create kubernetes clientset: %w", err)
	}
	return cs, cfg, nil
}
