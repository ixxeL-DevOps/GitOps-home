# GitOps-home
Home GitOps repository for infrastructure, clusters, stacks and so on and so forth

## Vcluster

When vlcuster is deployed, execute this command to update kubeconfig with the vcluster one:

```bash
vcluster connect vcluster-dev -n vk-dev --update-current=true --server=https://vcluster-dev.k8s-app.fredcorp.com --service-account admin --cluster-role cluster-admin --insecure --kube-config-context-name rke2-vk-dev
```

Then login to ArgoCD and add the cluster:
```bash
argocd login argocd.k8s-app.fredcorp.com --insecure
argocd cluster add vcluster_vcluster-dev_vk-dev_rke2-fredcorp --server argocd.k8s-app.fredcorp.com --insecure --name rke2-vk-dev
```

## Vault kubernetes auth for cert-manager


```bash
kubectl config view --raw -o jsonpath='{.clusters[?(@.name == "'"$(kubectl config current-context)"'")].cluster.certificate-authority-data}' | base64 --decode > ca.crt
token=$(kubectl get secret vault-auth -ojson | jq -r '.data.token' | base64 -d)
vault login -tls-skip-verify -address=https://vault.fredcorp.com
vault write -tls-skip-verify -address=https://vault.fredcorp.com auth/kubernetes/config token_reviewer_jwt=$token kubernetes_host=https://192.168.1.100:6443 kubernetes_ca_cert=@ca.crt
```
