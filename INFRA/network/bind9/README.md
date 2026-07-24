# XFSC BIND9

Uses an existing Kubernetes Secret (default: cert-manager-rfc2136).

The same TSIG secret is shared by:
- BIND9
- ExternalDNS
- cert-manager

No OpenBao init or ExternalSecret is required in this chart.
