package kube

import (
	"context"
	"encoding/base64"
	"fmt"
	"strings"

	metav1 "k8s.io/apimachinery/pkg/apis/meta/v1"
	"k8s.io/apimachinery/pkg/apis/meta/v1/unstructured"
	"k8s.io/apimachinery/pkg/runtime/schema"
	"k8s.io/apimachinery/pkg/util/yaml"
	"k8s.io/client-go/dynamic"
	"k8s.io/client-go/rest"
)

func DecodeBase64(input string) (string, error) {
	raw, err := base64.StdEncoding.DecodeString(input)
	if err != nil {
		return "", err
	}

	return string(raw), nil
}

func ApplyManifest(
	ctx context.Context,
	cfg *rest.Config,
	namespace string,
	yamlBase64 string,
) error {

	content, err := DecodeBase64(yamlBase64)
	if err != nil {
		return err
	}

	dyn, err := dynamic.NewForConfig(cfg)
	if err != nil {
		return err
	}

	docs := strings.Split(content, "---")

	for _, doc := range docs {

		doc = strings.TrimSpace(doc)

		if doc == "" {
			continue
		}

		var obj unstructured.Unstructured

		err := yaml.Unmarshal([]byte(doc), &obj)
		if err != nil {
			return err
		}

		gvr := schema.GroupVersionResource{
			Group:    obj.GroupVersionKind().Group,
			Version:  obj.GroupVersionKind().Version,
			Resource: strings.ToLower(obj.GetKind()) + "s",
		}

		_, err = dyn.Resource(gvr).
			Namespace(namespace).
			Create(ctx, &obj, metav1.CreateOptions{})

		if err != nil {
			return fmt.Errorf("apply resource %s: %w", obj.GetName(), err)
		}
	}

	return nil
}
