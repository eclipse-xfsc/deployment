package status

import (
	"context"
	"fmt"
	"strings"

	appsv1 "k8s.io/api/apps/v1"
	metav1 "k8s.io/apimachinery/pkg/apis/meta/v1"
	"k8s.io/client-go/kubernetes"
)

type ComponentResult struct {
	Component string `json:"component"`
	Kind      string `json:"kind"`
	Name      string `json:"name"`
	Ready     bool   `json:"ready"`
	Message   string `json:"message"`
	Error     string `json:"error,omitempty"`
}

func Check(ctx context.Context, cs *kubernetes.Clientset, namespace string, components []string) []ComponentResult {
	results := make([]ComponentResult, 0, len(components))
	for _, c := range components {
		kind, name, err := split(c)
		if err != nil {
			results = append(results, ComponentResult{Component: c, Ready: false, Error: err.Error()})
			continue
		}
		switch kind {
		case "deployment", "deploy":
			dep, err := cs.AppsV1().Deployments(namespace).Get(ctx, name, metav1.GetOptions{})
			results = append(results, deploymentResult(c, kind, name, dep, err))
		case "statefulset", "sts":
			sts, err := cs.AppsV1().StatefulSets(namespace).Get(ctx, name, metav1.GetOptions{})
			results = append(results, statefulsetResult(c, kind, name, sts, err))
		case "daemonset", "ds":
			ds, err := cs.AppsV1().DaemonSets(namespace).Get(ctx, name, metav1.GetOptions{})
			if err != nil { results = append(results, ComponentResult{Component: c, Kind: kind, Name: name, Ready: false, Error: err.Error()}); continue }
			ready := ds.Status.DesiredNumberScheduled == ds.Status.NumberReady
			results = append(results, ComponentResult{Component: c, Kind: kind, Name: name, Ready: ready, Message: fmt.Sprintf("ready %d/%d", ds.Status.NumberReady, ds.Status.DesiredNumberScheduled)})
		default:
			results = append(results, ComponentResult{Component: c, Kind: kind, Name: name, Ready: false, Error: "unsupported component kind; supported: deployment,statefulset,daemonset"})
		}
	}
	return results
}

func split(component string) (string, string, error) {
	parts := strings.Split(component, "/")
	if len(parts) != 2 || parts[0] == "" || parts[1] == "" { return "", "", fmt.Errorf("invalid component %q, expected kind/name", component) }
	return strings.ToLower(parts[0]), parts[1], nil
}

func deploymentResult(component, kind, name string, dep *appsv1.Deployment, err error) ComponentResult {
	if err != nil { return ComponentResult{Component: component, Kind: kind, Name: name, Ready: false, Error: err.Error()} }
	desired := int32(1); if dep.Spec.Replicas != nil { desired = *dep.Spec.Replicas }
	ready := dep.Status.ReadyReplicas >= desired && dep.Status.UpdatedReplicas >= desired && dep.Status.AvailableReplicas >= desired
	return ComponentResult{Component: component, Kind: kind, Name: name, Ready: ready, Message: fmt.Sprintf("ready %d/%d available %d updated %d", dep.Status.ReadyReplicas, desired, dep.Status.AvailableReplicas, dep.Status.UpdatedReplicas)}
}

func statefulsetResult(component, kind, name string, sts *appsv1.StatefulSet, err error) ComponentResult {
	if err != nil { return ComponentResult{Component: component, Kind: kind, Name: name, Ready: false, Error: err.Error()} }
	desired := int32(1); if sts.Spec.Replicas != nil { desired = *sts.Spec.Replicas }
	ready := sts.Status.ReadyReplicas >= desired && sts.Status.UpdatedReplicas >= desired
	return ComponentResult{Component: component, Kind: kind, Name: name, Ready: ready, Message: fmt.Sprintf("ready %d/%d updated %d", sts.Status.ReadyReplicas, desired, sts.Status.UpdatedReplicas)}
}
