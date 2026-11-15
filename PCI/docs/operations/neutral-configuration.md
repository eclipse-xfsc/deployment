# Neutral deployment configuration

This page describes the neutral revision prepared at version **0.5.0-rc.12**; the current source is `0.5.0-rc.16`. Operator-specific names, domains, email addresses, workstation paths, public IP addresses and live tenant/configuration identifiers have been removed. Official FACIS/XFSC identifiers, upstream contracts, source attribution and third-party licence notices are retained.

The examples in current and historical deployment guides are placeholders. Replace them before running deployment or wallet commands. Earlier release notes describe historical observations; neutral example URLs do not represent a publicly tested deployment.

| Example or input | Operator action |
|---|---|
| `pci.example.com`, `alpha-pci.example.com` | Supply provider and tenant hostnames under a domain you control. |
| `provider@example.com` | Supply the provider's mailbox. |
| `192.0.2.10`, `192.0.2.11` | Documentation-only IPv4 addresses; use actual reachable gateway/API addresses or omit optional overrides. |
| `/private/kubeconfig.yaml`, `/private/fullchain.pem`, `/private/privkey.pem` | Select private local files or mounted Secrets. |
| `$HOME/fap-pci` | Neutral working directory; override locations through script options or documented environment variables. |
| `xfsc-orce-operator` | Reserved example operator namespace; deploy PCI into its own dedicated namespace. |
| Kubernetes context and StorageClass | Select values from the intended cluster; never assume example names exist. |

`scripts/upgrade-artifacts.sh` defaults to `$HOME/fap-pci/deployment-private/pci-rc6-lifecycle.json` and `$HOME/fap-pci/deployment-test-notes`. Override them with `--config` / `--notes`, or `PCI_LIFECYCLE_CONFIG` / `PCI_TEST_NOTES`. The [lifecycle example](https://github.com/eclipse-xfsc/facis-fap-principal-credential-issuance/blob/main/automation/lifecycle.example.json) is a template; keep its completed copy and credential files outside the source tree.

## Software-wallet helper

`scripts/test-alpha-wallet.sh` keeps its established filename for compatibility and accepts target deployment inputs. It contains no live issuer, tenant UUID, configuration UUID or gateway address. Set these variables for a newly created **synthetic** `jwt_vc_json` credential using the OID4VCI 1.0 profile:

| Variable | Required value |
|---|---|
| `PCI_WALLET_ISSUER` | Exact HTTPS issuer URL, including the base path, without a trailing slash, user information, query or fragment. |
| `PCI_WALLET_TENANT_ID` | Tenant UUID from the selected deployment. |
| `PCI_WALLET_CONFIGURATION_ID` | UUID of the offered credential configuration. |
| `PCI_WALLET_SYNTHETIC_ONLY` | `true`, only after confirming the credential contains synthetic data. |
| `PCI_WALLET_GATEWAY_IP` | Optional IPv4 override; unset it to use DNS. HTTPS certificate verification remains enabled. |
| `PCI_TEST_NOTES` | Optional result directory; defaults to `$HOME/fap-pci/deployment-test-notes`. |

The helper validates these inputs before prompting or making requests. It silently prompts for the fresh credential offer and tenant `fap_pci_session` cookie value. HTTP/1.1 and verified TLS 1.3 are retained. Result logs expose endpoint paths, status codes and allowlisted error codes; offers, cookies, tokens, credentials and private keys stay in memory or private temporary files deleted on exit. A wallet run consumes its offer; review an uncertain request outcome before creating a new offer. Software-wallet PASS does not establish PCM, cluster or complete requirement acceptance.

For the current upgrade sequence see [rc.12 upgrade](https://github.com/eclipse-xfsc/facis-fap-principal-credential-issuance/blob/9dadba418006ca1825f3a5cffe4a193a81a01e5a/docs/operations/upgrade-0.5.0-rc.12.md). For executed checks and limits see [neutral revision](https://github.com/eclipse-xfsc/facis-fap-principal-credential-issuance/blob/9dadba418006ca1825f3a5cffe4a193a81a01e5a/docs/release/neutral-revision.md).
