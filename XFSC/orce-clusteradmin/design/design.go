package design

import . "goa.design/goa/v3/dsl"

var _ = API("orce-clusteradmin", func() {
	Title("orce-clusteradmin")
	Description("Remote Kubernetes/Helm cluster admin installer API")
	Server("orce-clusteradmin", func() {
		Host("localhost", func() { URI("http://localhost:8080") })
	})
})

var OperationResponse = Type("OperationResponse", func() {
	Attribute("success", Boolean)
	Attribute("message", String)
	Attribute("stdout", String)
	Attribute("stderr", String)
	Attribute("errors", ArrayOf(String))
	Attribute("data", Any)
	Required("success")
})

var HelmInstallRequest = Type("HelmInstallRequest", func() {
	Attribute("kubeconfigBase64", String, "Base64 encoded kubeconfig")
	Attribute("namespace", String, func() { Default("default") })
	Attribute("releaseName", String, "Helm release name")
	Attribute("chartRef", String, "Helm chart reference, e.g. argo/argo-cd")
	Attribute("chartVersion", String, "Optional chart version")
	Attribute("valuesYaml", String, "Optional values.yaml content")
	Attribute("createNamespace", Boolean, func() { Default(true) })
	Required("kubeconfigBase64", "releaseName", "chartRef")
})

var HelmUninstallRequest = Type("HelmUninstallRequest", func() {
	Attribute("kubeconfigBase64", String)
	Attribute("namespace", String, func() { Default("default") })
	Attribute("releaseName", String)
	Required("kubeconfigBase64", "releaseName")
})

var InstallationsRequest = Type("InstallationsRequest", func() {
	Attribute("kubeconfigBase64", String)
	Attribute("namespace", String, "Optional namespace. Empty means all namespaces.")
	Required("kubeconfigBase64")
})

var ComponentStatusRequest = Type("ComponentStatusRequest", func() {
	Attribute("kubeconfigBase64", String)
	Attribute("namespace", String)
	Attribute("components", ArrayOf(String), "Examples: deployment/argocd-server, statefulset/argocd-application-controller")
	Required("kubeconfigBase64", "namespace", "components")
})

var KubectlApplyRequest = Type("KubectlApplyRequest", func() {
	Attribute("kubeconfigBase64", String)
	Attribute("namespace", String, func() {
		Default("default")
	})
	Attribute("yamlBase64", String, "Base64 encoded Kubernetes YAML")
	Required("kubeconfigBase64", "yamlBase64")
})

var KubectlRemoveRequest = Type("KubectlRemoveRequest", func() {
	Attribute("kubeconfigBase64", String)
	Attribute("namespace", String, func() {
		Default("default")
	})
	Attribute("kind", String, "deployment, service, secret, configmap, ...")
	Attribute("name", String)
	Required("kubeconfigBase64", "kind", "name")
})

var _ = Service("clusteradmin", func() {
	Description("Cluster admin API")

	Method("health", func() {
		Result(OperationResponse)
		HTTP(func() { GET("/health"); Response(StatusOK) })
	})

	Method("install", func() {
		Payload(HelmInstallRequest)
		Result(OperationResponse)
		HTTP(func() {
			POST("/install")
			Body(func() {

				Attribute("kubeconfigBase64")
				Attribute("namespace")
				Attribute("releaseName")
				Attribute("chartRef")
				Attribute("valuesYaml")
			})
			Response(StatusOK)
		})
	})

	Method("uninstall", func() {
		Payload(HelmUninstallRequest)
		Result(OperationResponse)
		HTTP(func() {
			POST("/uninstall")
			Body(func() {
				Attribute("kubeconfigBase64")
				Attribute("namespace")
				Attribute("releaseName")
			})
			Response(StatusOK)
		})
	})

	Method("installations", func() {
		Payload(InstallationsRequest)
		Result(OperationResponse)
		HTTP(func() {
			POST("/installations")
			Body(func() {

				Attribute("kubeconfigBase64")
				Attribute("namespace")
			})
			Response(StatusOK)
		})
	})

	Method("checkComponentStatus", func() {
		Payload(ComponentStatusRequest)
		Result(OperationResponse)
		HTTP(func() {
			POST("/checkComponentStatus")
			Body(func() {

				Attribute("kubeconfigBase64")
				Attribute("namespace")
				Attribute("components")
			})
			Response(StatusOK)
		})
	})

	Method("apply", func() {
		Payload(KubectlApplyRequest)
		Result(OperationResponse)

		HTTP(func() {
			POST("/apply")

			Body(func() {
				Attribute("kubeconfigBase64")
				Attribute("namespace")
				Attribute("yamlBase64")
			})

			Response(StatusOK)
		})
	})

	Method("remove", func() {
		Payload(KubectlRemoveRequest)
		Result(OperationResponse)

		HTTP(func() {
			POST("/remove")
			Body(func() {
				Attribute("kubeconfigBase64")
				Attribute("namespace")
				Attribute("kind")
				Attribute("name")
			})
			Response(StatusOK)
		})
	})
})
