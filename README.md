# GitOps-home
Home GitOps repository for infrastructure, clusters, stacks and so on and so forth



## Structure

Ce repository git est le repo principal ArgoCD. Il contient la definition du deploiement ArgoCD lui meme ainsi que les definitions des differents objets ArgoCD (`Application`, `ApplicationSet`, `AppProject`...etc).

La structure du repository est la suivante :

```bash
.
├── argoApps
├── argoClusters
├── argoProjects
├── argoRepositories
├── bootstrap
│   ├── Chart.lock
│   ├── charts
│   │   ├── argo-cd-x.y.z.tgz
│   │   ├── argocd-apps-x.y.z.tgz
│   │   └── argocd-image-updater-x.y.z.tgz
│   ├── Chart.yaml
│   └── values-bootstrap.yaml
├── config
│   ├── prd
│   │   ├── namespace-A
│   │   ├── namespace-B
│   │   └── namespace-C
│   └── stg
│       ├── namespace-A
│       ├── namespace-B
│       └── namespace-C
└── README.md
```

L'installation d'ArgoCD respecte le pattern app of apps recommande par ArgoCD 
- https://argo-cd.readthedocs.io/en/stable/operator-manual/cluster-bootstrapping/#app-of-apps-pattern

Ce pattern est legerement ameliore pour des conditions de maintenance et d'evolution ideales.

Chaque dossier est destine a un usage specifique :

- `argoApps` : contient la definition de toutes les applications (les objets `Application` et `ApplicationSet`)
- `argoClusters` : contient les informations de connexion aux differents clusters kubernetes auquels ArgoCD a acces (Utiliser des `ExternalSecret` quand c'est necessaire)
- `argoProjects` : contient la definition des projets Argocd (les objets `AppProject`)
- `argoRepositories` : contient les informations de connexion aux differents repositories ou registries auquels ArgoCD peut se connecter (Utiliser des `ExternalSecret` quand c'est necessaire)
- `bootstrap` : contient les manifests de deploiement de l'instance ArgoCD au format `Helm` ici.
- `config` : contient la configuration specifique de chaque cluster

### Bootstrap : premiere installation

Avant de proceder a l'installation, il est possible de creer un mot de passe personnalise via cette commande :

```bash
htpasswd -nbBC 10 "" $ARGO_PWD | tr -d ':\n' | sed 's/$2y/$2a/'
```

Puis de specifier sa valeur hashee dans le fichier `values-bootstrap.yaml` :
```yaml
argo-cd:
  configs:
    secret:
      argocdServerAdminPassword: "<hashed-value>"
```

La premiere installation d'ArgoCD est la seule et unique fois (sauf cas extremes/speciaux de recovery ou maintenance specifique) ou la CLI helm est utilisee pour proceder a l'installation. Toutes les mises a jour suivantes sont faites via git.

```bash
helm upgrade -i argocd bootstrap/ -n argocd --create-namespace -f boostrap/values-bootstrap.yaml --set apps.enabled=false --set updater.enabled=false
```

Cette commande permets d'installer uniquement ArgoCD, puis executer ensuite :
```bash
helm upgrade -i argocd bootstrap/ -n argocd --create-namespace -f boostrap/values-bootstrap.yaml --set apps.enabled=true --set updater.enabled=true
```

Cette commande permets de mettre en place le pattern App of Apps et d'installer egalement image updater.


### Configuration ArgoCD

ArgoCD est installe via le Helm chart communautaire :
- https://github.com/argoproj/argo-helm.git

Le dossier `bootstrap` est tres important, c'est dans ce dossier qu'on modifie la configuration de ArgoCD lui-meme via le fichier `values-bootstrap.yaml`.

Pour mettre a jour la configuration de ArgoCD, simplement modifier les valeurs dans le fichier `values-bootstrap.yaml` puis push les modifications sur le repo git et attendre la synchronisation ArgoCD (ou bien la forcer pour aller plus vite).

### Mise a jour Helm chart ArgoCD

Le fichier `Chart.yaml` est egalement important pour mettre a jour la version du Helm chart de ArgoCD ainsi que des autres charts utilisees. 

Pour mettre a jour le helm chart, executer les commandes suivantes apres avoir mis a jour la version dans le fichier `Chart.yaml` :

```bash
helm dep update
```

### Configuration cluster

Vous pouvez ajouter de la config cluster dans le dossier `config`. Ce dossier est destine a recevoir des objets qui ne sont pas lies a ArgoCD mais qui peuvent etre utiles dans votre cluster comme des `Secret` ou `ConfigMap`.

Il faut override le namespace dans ces manifest en specifiant en dur le namespace cible :

```yaml
---
apiVersion: external-secrets.io/v1beta1
kind: ExternalSecret
metadata:
  name: dockerhub-creds
  namespace: argocd
```

### Creation d'une nouvelle application

Pour creer une nouvelle application, simplement ajouter un fichier de type `Application` ou `ApplicationSet` dans le dossier `argoApps` puis synchroniser la brique application en question dans ArgoCD (ou attendre c'est automatique).

### Creation automatique et dynamique

Cette section explique comment rendre dynamique vos creations d'applications metier sans pour autant laisser la main entierement aux developpeurs. Voici une structure de depart que vous pouvez utiliser pour organiser correctement votre repo applicatif:

Le pattern structurel des dossiers est le suivant :

<CSP>/<cluster>/<namespace>/<application-name>

```bash
.
├── gke
│   ├── dev
│   │   ├── namespace-a
│   │   │   ├── app-a
│   │   │   └── app-b
│   │   └── namespace-b
│   │       ├── app-a
│   │       └── app-b
│   ├── prd
│   │   └── namespace-a
│   │       ├── app-a
│   │       └── app-b
│   └── stg
│       ├── namespace-a
│       │   ├── app-a
│       │   └── app-b
│       └── namespace-b
│           ├── app-a
│           └── app-b
└── README.md
```

Objet `ApplicationSet` pour la creation dynamique de ressources dans le cluster de staging, namespace quanti-dev (environnement `developpement`):

```yaml
---
apiVersion: argoproj.io/v1alpha1
kind: ApplicationSet
metadata:
  name: dev-apps
  namespace: argocd
spec:
  generators:
    - git:
        repoURL: 'https://github.com/ixxeL-DevOps/GitOps-apps.git'
        revision: main
        directories:
          - path: 'gke/dev/*/*'
  template:
    metadata:
      name: '{{path.basenameNormalized}}-dev'
      annotations:
        argocd-image-updater.argoproj.io/app.update-strategy: latest
        argocd-image-updater.argoproj.io/app.allow-tags: regexp:^dev-.*
        argocd-image-updater.argoproj.io/git-branch: main
        argocd-image-updater.argoproj.io/image-list: 'app=europe-west9-docker.pkg.dev/repo/test/{{path.basenameNormalized}}'
        argocd-image-updater.argoproj.io/write-back-method: git
        notifications.argoproj.io/subscribe.on-sync-succeeded.slack: infra-deploiements
      finalizers: []
    spec:
      project: dev-apps
      destination:
        name: '{{path[1]}}'
        namespace: '{{path[2]}}'
      source:
        repoURL: 'https://github.com/ixxeL-DevOps/GitOps-apps.git'
        path: '{{path}}'
        targetRevision: main
      syncPolicy:
        automated:
          prune: true
          selfHeal: true
        syncOptions:
          - Validate=true
          - PruneLast=false
          - RespectIgnoreDifferences=true
          - Replace=false
          - ApplyOutOfSyncOnly=true
          - CreateNamespace=true
          - ServerSideApply=true
```

Objet `ApplicationSet` pour la creation dynamique de ressources dans le cluster de staging, namespace quanti (environnement `staging`):

```yaml
---
apiVersion: argoproj.io/v1alpha1
kind: ApplicationSet
metadata:
  name: stg-apps
  namespace: argocd
spec:
  generators:
    - git:
        repoURL: 'https://github.com/ixxeL-DevOps/GitOps-apps.git'
        revision: main
        directories:
          - path: 'gke/stg/*/*'
  template:
    metadata:
      name: '{{path.basenameNormalized}}-stg'
      annotations:
        argocd-image-updater.argoproj.io/app.update-strategy: latest
        argocd-image-updater.argoproj.io/app.allow-tags: regexp:^v1.[0-9]+.[0-9]+-rc[0-9]+
        argocd-image-updater.argoproj.io/git-branch: main
        argocd-image-updater.argoproj.io/image-list: 'app=europe-west9-docker.pkg.dev/repo/test/{{path.basenameNormalized}}'
        argocd-image-updater.argoproj.io/write-back-method: git
        notifications.argoproj.io/subscribe.on-sync-succeeded.slack: infra-deploiements
      finalizers: []
    spec:
      project: stg-apps
      destination:
        name: '{{path[1]}}'
        namespace: '{{path[2]}}'
      source:
        repoURL: 'https://github.com/ixxeL-DevOps/GitOps-apps.git'
        path: '{{path}}'
        targetRevision: main
      syncPolicy:
        automated:
          prune: true
          selfHeal: true
        syncOptions:
          - Validate=true
          - PruneLast=false
          - RespectIgnoreDifferences=true
          - Replace=false
          - ApplyOutOfSyncOnly=true
          - CreateNamespace=true
          - ServerSideApply=true
```

Objet `ApplicationSet` pour la creation dynamique de ressources dans le cluster de prod, namespace quanti (environnement `production`):

```yaml
---
apiVersion: argoproj.io/v1alpha1
kind: ApplicationSet
metadata:
  name: prd-apps
  namespace: argocd
spec:
  generators:
    - git:
        repoURL: 'https://github.com/ixxeL-DevOps/GitOps-apps.git'
        revision: main
        directories:
          - path: 'gke/prd/*/*'
  template:
    metadata:
      name: '{{path.basenameNormalized}}'
      annotations:
        argocd-image-updater.argoproj.io/app.update-strategy: semver
        argocd-image-updater.argoproj.io/git-branch: main
        argocd-image-updater.argoproj.io/image-list: 'app=europe-west9-docker.pkg.dev/repo/test/{{path.basenameNormalized}}v1.x.x'
        argocd-image-updater.argoproj.io/write-back-method: git
        notifications.argoproj.io/subscribe.on-sync-succeeded.slack: infra-deploiements
      finalizers: []
    spec:
      project: prd-apps
      destination:
        name: '{{path[1]}}'
        namespace: '{{path[2]}}'
      source:
        repoURL: 'https://github.com/ixxeL-DevOps/GitOps-apps.git'
        path: '{{path}}'
        targetRevision: main
      syncPolicy:
        automated:
          prune: true
          selfHeal: true
        syncOptions:
          - Validate=true
          - PruneLast=false
          - RespectIgnoreDifferences=true
          - Replace=false
          - ApplyOutOfSyncOnly=true
          - CreateNamespace=true
          - ServerSideApply=true
```


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
token=$(kubectl get secret vault-auth -n cert-manager -ojson | jq -r '.data.token' | base64 -d)
vault login -tls-skip-verify -address=https://vault.fredcorp.com
vault write -tls-skip-verify -address=https://vault.fredcorp.com auth/kubernetes/config token_reviewer_jwt=$token kubernetes_host=https://192.168.1.110:6443 kubernetes_ca_cert=@ca.crt
```

