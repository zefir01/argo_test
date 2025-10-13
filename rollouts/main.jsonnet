local argo = import '../libs/argo.libsonnet';
local c = import '../libs/cilium.libsonnet';
local k8s = import '../libs/k8s.libsonnet';
local o = import '../libs/oauth-proxy.libsonnet';

[
  argo.app_helm(
    'argo-rollouts',
    'argo-rollouts',
    'https://argoproj.github.io/argo-helm',
    'argo-rollouts',
    '2.40.5',
    valuesObject={
      dashboard: {
        enabled: true,
      },
    },
    wave=10
  ),

  o.github_pod(
    'oauth',
    'zefir01',
    'hubble',
    'pstukalov-test.com',
    'http://argo-rollouts-dashboard:3100',
    'oauth-proxy',
    replicas=1
  ),

  c.httpRoute('rollouts', ['rollouts.pstukalov-test.com'], [
    c.rulePrefix('/', 'oauth'),
  ], namespace='argo-rollouts', wave=30),
]
