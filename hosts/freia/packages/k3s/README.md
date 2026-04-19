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
   complete:

   ```sh
   k3s kubectl -n kube-system delete helmchart <chart>
   k3s kubectl -n kube-system get jobs | grep <chart>
   ```

3. Delete the objects from plain manifests (`IngressRoute`, `PersistentVolume`,
   `ClusterRoleBinding`, ...), and the Secrets synced by `kubectl.secrets`.
   Uninstalling the release doesn't remove them. If
   the service had its own namespace, deleting the namespace removes everything
   in it, **including PVC data**:

   ```sh
   k3s kubectl -n <namespace> delete ingressroute <name>
   k3s kubectl delete namespace <namespace>   # only if the namespace was the service's own
   ```

   Never delete shared namespaces such as `default` or `kube-system`.

4. Delete k3s's Addon records, and the chart file:

   ```sh
   k3s kubectl -n kube-system delete addon <chart> <manifest>
   rm /var/lib/rancher/k3s/server/static/charts/<chart>.tgz
   ```

5. Check that nothing is left:

   ```sh
   k3s kubectl get all,ingressroute,pvc,secret -A | grep -i <chart>
   k3s kubectl get pv,clusterrole,clusterrolebinding,crd | grep -i <chart>
   k3s kubectl -n kube-system get helmchart,addon,jobs | grep -i <chart>
   ```
