local argo = import '../libs/argo.libsonnet';
local access = import '../libs/eks_access.libsonnet';
local k8s = import '../libs/k8s.libsonnet';
local k = import '../libs/karpenter.libsonnet';
local c =import '../libs/cilium.libsonnet';
local cm = import '../libs/cert-manager.libsonnet';


local e = import '../libs/env.libsonnet';


[
  argo.app(
    'snapshots-crd',
    'snapshots-crd',
    'apps/snapshots-crd',
  ),

  argo.app_helm(
    'metrics-server',
    'kube-system',
    'https://kubernetes-sigs.github.io/metrics-server/',
    'metrics-server',
    '3.8.2',
    helm_params=[
      argo.var('replicas', '1'),
      argo.var('metrics.enabled', 'true'),
      argo.var('serviceMonitor.enabled', 'false'),
      argo.var('resources.limits.cpu', '300m'),
      argo.var('resources.limits.memory', '256Mi'),
      argo.var('resources.requests.cpu', '100m'),
      argo.var('resources.requests.memory', '128Mi'),
    ],
    wave=10
  ),

  k.nodeClass('default'),

  k.nodePool('default', wave=10),

  argo.app_helm(
    'secret-generator',
    'secret-generator',
    'https://helm.mittwald.de',
    'kubernetes-secret-generator',
    '3.4.0',
    wave=20
  ),

  argo.app_helm(
    'patch-operator',
    'patch-operator',
    'https://redhat-cop.github.io/patch-operator',
    'patch-operator',
    '0.1.9',
    wave=20,
    helm_params=[
      argo.var('enableCertManager', 'true'),
    ]
  ),
  k8s.sa('patch', namespace='patch-operator', wave=21),
  k8s.clusterRoleBinding('patch', 'cluster-admin', 'patch', 'patch-operator', wave=21),

  argo.app_helm(
    'reloader',
    'reloader',
    'https://stakater.github.io/stakater-charts',
    'reloader',
    '0.0.126',
    wave=20
  ),

  argo.appKustomize('prometheus-operator-crds',
                    'prometheus',
                    argo.config.argo_repo,
                    'apps/prometheus-crds',
                    replace=true,
                    applyOutOfSyncOnly=true,
                    targetRevision=argo.config.argo_branch,
                    wave=10),

  argo.app_helm(
    'prometheus-operator',
    'prometheus',
    'https://prometheus-community.github.io/helm-charts',
    'kube-prometheus-stack',
    '35.0.3',
    wave=20,
    helm_params=[
      argo.var('kubeApiServer.enabled', 'false'),
      argo.var('prometheus.serviceAccount.annotations.eks\\.amazonaws\\.com/role-arn', argo.config.prometheus_irsa_arn),
      argo.var('prometheus.serviceAccount.name', 'prometheus-server'),
      argo.var('grafana.enabled', 'false'),
      argo.var('alertmanager.enabled', 'false'),
      argo.var('prometheus.prometheusSpec.remoteWrite[0].url', argo.config.amp_url + 'api/v1/remote_write'),
      argo.var('prometheus.prometheusSpec.remoteWrite[0].sigv4.region', argo.config.region),
      argo.var('prometheus.prometheusSpec.remoteWrite[0].writeRelabelConfigs[0].targetLabel', 'cluster_name'),
      argo.var('prometheus.prometheusSpec.remoteWrite[0].writeRelabelConfigs[0].action', 'replace'),
      argo.var('prometheus.prometheusSpec.remoteWrite[0].writeRelabelConfigs[0].replacement', argo.config.cluster_name),
      argo.var('prometheus.prometheusSpec.retention', '3h'),

      argo.var('prometheus.prometheusSpec.resources.requests.cpu', '10m'),
      argo.var('prometheus.prometheusSpec.resources.requests.memory', '128Mi'),

      argo.var('prometheusOperator.prometheusConfigReloader.resources.requests.cpu', '10m'),
      //argo.var("prometheusOperator.prometheusConfigReloader.resources.requests.memory", "128Mi"),

      argo.var('prometheusOperator.admissionWebhooks.patch.resources.requests.cpu', '10m'),
      argo.var('prometheusOperator.admissionWebhooks.patch.resources.requests.memory', '128Mi'),

      argo.var('prometheusOperator.resources.requests.cpu', '10m'),
      argo.var('prometheusOperator.resources.requests.memory', '128Mi'),

      argo.var('prometheus.prometheusSpec.podMonitorSelectorNilUsesHelmValues', 'false'),
      argo.var('prometheus.prometheusSpec.serviceMonitorSelectorNilUsesHelmValues', 'false'),
    ],
    skipCrds=true,
    selfHeal=false,
    ignoreDifferences=[
      {
        group: 'admissionregistration.k8s.io',
        kind: 'MutatingWebhookConfiguration',
        name: 'prometheus-operzator-kube-p-admission',
        jqPathExpressions: [
          '.webhooks[0].failurePolicy',
        ],
      },
      {
        group: 'admissionregistration.k8s.io',
        kind: 'ValidatingWebhookConfiguration',
        name: 'prometheus-operator-kube-p-admission',
        jqPathExpressions: [
          '.webhooks[0].failurePolicy',
        ],
      },
      {
        group: 'monitoring.coreos.com',
        kind: 'ServiceMonitor',
        name: 'prometheus-operator-kube-p-kubelet',
        jqPathExpressions: [
          '.spec.endpoints[].relabelings[].action',
        ],
      },
    ],
  ),

  argo.app_helm(
    'node-problem-detector',
    'node-problem-detector',
    'https://charts.deliveryhero.io',
    'node-problem-detector',
    '2.3.12',
    wave=20,
  ),

  argo.app_helm(
    'vpa',
    'vpa',
    'https://charts.fairwinds.com/stable',
    'vpa',
    '4.9.0',
    wave=20,
  ),

  c.gateway('main', 'cilium', wave=20),
  cm.letsEncryptIssuerCilium('cilium', 'pstukalov@oncetrl.com','main', 'argo' , wave=20),
  argo.app('hubble', 'hubble', 'hubble', wave=30),
  argo.app('rollouts', 'rollouts', 'rollouts', wave=30),

  argo.app('test-payload', 'test-payload', 'test-payload', wave=30, istio=false),
  argo.app('rollouts-test', 'rollouts-test', 'rollouts-test', wave=30, istio=false),

]