# Kyverno
To enable kyverno within the namespace use: 
```
kubectl label namespace my-app \

  image-signature-policy.xsfc.io/enabled=true
```