# homelab

My home Kubernetes cluster, running k3s on two machines. Everything in it is deployed by Argo CD from this repo.

Still a work in progress, see the [roadmap](#roadmap).

## Cluster

Two bare-metal nodes running Ubuntu Server: one control plane node and one worker (more planned). A 1 TB external HDD on the control plane node provides persistent storage. For now it's local to that node; the plan is to share it over NFS as more nodes get added. Apps are reached on the home network through the built-in Traefik ingress.

## How it works

Argo CD uses the **app-of-apps** pattern:

```mermaid
flowchart LR
    root["root.yaml<br/>(applied once by hand)"] --> apps["apps/<br/>one Application per app"]
    apps --> a1["Argo CD itself (Helm chart)"]
    apps --> a2["monitoring (Helm chart)"]
    apps --> a3["jellyfin (Helm chart)"]
    apps --> a4["sonarr/, radarr/, ... (plain YAML)"]
    apps --> a5["namespaces/, hdd/, node-storage/<br/>(cluster infrastructure)"]
```

- `root.yaml` is the only thing applied by hand. It watches `apps/`.
- Each file in `apps/` is an Argo CD `Application` pointing at either a folder in this repo (plain manifests) or a pinned Helm chart with inline values.
- Cluster infrastructure (namespaces, StorageClasses, PersistentVolumes) is managed the same way as apps.
- Every Application has **automated sync, prune and self-heal**: manual changes in the cluster get reverted to match Git.
- **Argo CD manages itself**: its own Helm release is defined in `apps/argocd.yaml`, so upgrading Argo is a one-line version bump.
- Chart and image versions are pinned, so nothing upgrades unless I change it in Git.

## What's running

| App | What it does |
|-----|--------------|
| Argo CD | GitOps controller (self-managed via Helm) |
| Prometheus + Grafana | Cluster monitoring (kube-prometheus-stack, tuned for k3s) |
| Jellyfin | Media server |
| Sonarr, Radarr, Prowlarr, Seerr | Media library automation |
| qBittorrent | Downloads, with all traffic routed through a Gluetun VPN sidecar |
| whoami | Test app used to verify ingress and load balancing across both nodes |

## Storage

- **External HDD** (`hdd/`): a `local-hdd` StorageClass with hand-written PersistentVolumes pinned to the mini PC. Used for Prometheus data and the shared media library. Data PVs use `Retain` and are annotated so Argo never prunes or deletes them.
- **Node-local storage** (`node-storage/`): a `local-provisioned` StorageClass (k3s local-path provisioner, `Retain`) for small app config volumes, created automatically on whichever node the pod lands on.
- Prometheus deliberately uses local disk, not network storage, to avoid database corruption.

## Roadmap

- [X] Backups with Velero to S3 (bucket and IAM user provisioned with Terraform)
- [ ] Sealed Secrets, so encrypted secrets (VPN, Grafana, Argo) can live in this repo instead of being created by hand
- [ ] Alerting via Alertmanager (Discord + email)
- [ ] Automated dependency updates with Renovate
- [ ] TLS certificates with cert-manager
- [ ] Remote access to the cluster
- [ ] More nodes
- [ ] More services: Uptime Kuma, Pi-hole
