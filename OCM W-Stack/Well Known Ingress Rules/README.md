# Important Note

To bring the ingress rules to work, dont forget to define in the ingress controller configuration itself the following attributes: 

```
data:
  allow-snippet-annotations: "true"
  annotations-risk-level: Critical

```