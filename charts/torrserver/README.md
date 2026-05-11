# TorrServer Helm Chart

[![Helm](https://img.shields.io/badge/helm-v3-blue)](https://helm.sh)

Deploys [TorrServer](https://github.com/YouROK/TorrServer) — a torrent stream server — on Kubernetes.

## TL;DR

```bash
helm install torrserver ./torrserver
```

## Introduction

This chart deploys TorrServer on a Kubernetes cluster using the Helm package manager.
TorrServer streams torrent files via HTTP without needing to download the full file first.

## Prerequisites

- Kubernetes 1.21+
- Helm 3.2+
- PersistentVolume provisioner (for persistence)

## Installing the Chart

```bash
# From local directory
helm install torrserver ./torrserver

# With custom values
helm install torrserver ./torrserver -f my-values.yaml

# With inline overrides
helm install torrserver ./torrserver \
  --set persistence.data.size=50Gi \
  --set service.type=LoadBalancer
```

## Uninstalling the Chart

```bash
helm uninstall torrserver
```

> **Note:** PVCs are NOT deleted automatically. Delete them manually if needed:
> ```bash
> kubectl delete pvc torrserver-config torrserver-data
> ```

## Configuration

| Parameter | Description | Default |
|---|---|---|
| `image.repository` | Container image repository | `ghcr.io/yourok/torrserver` |
| `image.tag` | Image tag (defaults to chart appVersion) | `""` |
| `image.pullPolicy` | Image pull policy | `IfNotPresent` |
| `replicaCount` | Number of replicas | `1` |
| `config.port` | HTTP port TorrServer listens on | `8090` |
| `config.confPath` | Config directory inside container | `/opt/ts/config` |
| `config.torrDir` | Torrents cache directory | `/opt/ts/torrents` |
| `config.httpAuth` | Enable HTTP Basic Auth | `false` |
| `config.readOnlyDb` | Enable read-only DB mode | `false` |
| `config.dontKill` | Don't kill server on OS signal | `true` |
| `ssl.enabled` | Enable HTTPS | `false` |
| `ssl.port` | HTTPS port | `8091` |
| `ssl.existingSecret` | Secret with `tls.crt` and `tls.key` | `""` |
| `persistence.config.enabled` | Enable config PVC | `true` |
| `persistence.config.size` | Config PVC size | `1Gi` |
| `persistence.config.storageClass` | Storage class for config PVC | `""` |
| `persistence.config.existingClaim` | Use existing PVC for config | `""` |
| `persistence.data.enabled` | Enable data/torrents PVC | `true` |
| `persistence.data.size` | Data PVC size | `20Gi` |
| `persistence.data.storageClass` | Storage class for data PVC | `""` |
| `persistence.data.existingClaim` | Use existing PVC for data | `""` |
| `service.type` | Kubernetes service type | `ClusterIP` |
| `service.port` | Service port | `8090` |
| `service.torrentPort.enabled` | Expose raw torrent port | `false` |
| `service.torrentPort.port` | Raw torrent port | `32000` |
| `ingress.enabled` | Enable Ingress | `false` |
| `ingress.className` | Ingress class name | `""` |
| `ingress.hosts` | Ingress hosts configuration | see `values.yaml` |
| `ingress.tls` | Ingress TLS configuration | `[]` |
| `resources.requests.cpu` | CPU request | `100m` |
| `resources.requests.memory` | Memory request | `256Mi` |
| `resources.limits.cpu` | CPU limit | `2000m` |
| `resources.limits.memory` | Memory limit | `2Gi` |
| `autoscaling.enabled` | Enable HPA | `false` |
| `nodeSelector` | Node selector | `{}` |
| `tolerations` | Pod tolerations | `[]` |
| `affinity` | Pod affinity rules | `{}` |
| `extraEnv` | Extra environment variables | `[]` |

## Examples

### Expose via LoadBalancer

```yaml
service:
  type: LoadBalancer
  port: 8090
```

### Expose via Ingress with TLS (cert-manager)

```yaml
ingress:
  enabled: true
  className: nginx
  annotations:
    cert-manager.io/cluster-issuer: letsencrypt-prod
  hosts:
    - host: torrserver.mydomain.com
      paths:
        - path: /
          pathType: Prefix
  tls:
    - secretName: torrserver-tls
      hosts:
        - torrserver.mydomain.com
```

### Use existing PVCs

```yaml
persistence:
  config:
    existingClaim: my-torrserver-config
  data:
    existingClaim: my-torrserver-data
```

### Enable HTTP Basic Auth

First create the `accs.db` file inside the config PVC, then:

```yaml
config:
  httpAuth: true
```

### Large storage with custom StorageClass

```yaml
persistence:
  data:
    storageClass: fast-ssd
    size: 200Gi
```

## Security

- Runs as non-root user (`uid=1000`)
- `allowPrivilegeEscalation: false`
- All Linux capabilities dropped
- `readOnlyRootFilesystem: false` (TorrServer writes temp files)

## Upgrading

```bash
helm upgrade torrserver ./torrserver -f my-values.yaml
```

> The Deployment uses `strategy: Recreate` to avoid two pods sharing the same PVC simultaneously.
