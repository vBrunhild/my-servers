# k3s services

## Removing a service

Deleting a service from the flake is **not enough**. NixOS only creates the
manifest links in `/var/lib/rancher/k3s/server/manifests/` and never deletes
them, and k3s never deletes cluster objects when a manifest disappears. The
service keeps running until you clean it up by hand.

Run these steps after removing the service's `.nix` file and its `imports`
entry, and deploying. `<chart>` is the `autoDeployCharts` attribute name and
`<manifest>` is each `services.k3s.manifests` attribute name. Run on the server
as root:

1. Remove the manifest links so k3s stops reapplying them:

   ```sh
   rm /var/lib/rancher/k3s/server/manifests/{<chart>,<manifest>}.yaml
   ```

2. Uninstall the Helm release, and wait for the `helm-delete-<chart>` job to
   complete. The job is small and removes itself when done, so if it's already
   gone, check that the release objects (Deployment, Service, release Secrets)
   are gone instead:

   ```sh
   k3s kubectl -n kube-system delete helmchart <chart>
   k3s kubectl -n kube-system get jobs | grep <chart>
   ```

3. Delete the objects from plain manifests (`IngressRoute`, `PersistentVolume`,
   `ClusterRoleBinding`, ...), and the Secrets synced by `kubectl.secrets`.
   Uninstalling the release doesn't remove them. Their names often don't
   contain `<chart>`, so read `metadata.name` from each manifest in the
   service's `.nix` file (or from the removed link's old store path) instead of
   guessing. Cluster-scoped objects survive a namespace delete, and so do
   Secrets synced into a different namespace (e.g. `kube-system`). If the
   service had its own namespace, deleting the namespace removes everything in
   it, **including PVC data**:

   ```sh
   k3s kubectl -n <namespace> delete ingressroute <name>
   k3s kubectl delete clusterrolebinding <name>
   k3s kubectl -n <secret-namespace> delete secret <name>
   k3s kubectl delete namespace <namespace>   # only if the namespace was the service's own
   ```

   Never delete shared namespaces such as `default` or `kube-system`.

4. Delete k3s's Addon records, and the chart file:

   ```sh
   k3s kubectl -n kube-system delete addon <chart> <manifest>
   rm /var/lib/rancher/k3s/server/static/charts/<chart>.tgz
   ```

5. Check that nothing is left. Also grep for the names of the plain manifests
   and secrets you deleted in step 3, since they may not contain `<chart>`:

   ```sh
   k3s kubectl get all,ingressroute,pvc,secret -A | grep -i <chart>
   k3s kubectl get pv,clusterrole,clusterrolebinding,crd | grep -i <chart>
   k3s kubectl -n kube-system get helmchart,addon,jobs,secret | grep -i <chart>
   ```
