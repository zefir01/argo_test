local argo = import '../libs/argo.libsonnet';
local c = import '../libs/cilium.libsonnet';
local k8s = import '../libs/k8s.libsonnet';

[
  argo.app_helm(
    'argo-rollouts',
    'argo-rollouts',
    'https://argoproj.github.io/argo-helm',
    'argo-rollouts',
    '2.40.5',
    values={
      dashboard: {
        enabled: true,
      },
    },
    wave=10
  ),
]
