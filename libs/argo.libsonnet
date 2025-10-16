local k8s = import 'k8s.libsonnet';

local terraform_config = if std.extVar('env_name')=='dev' then std.parseYaml(importstr '../argo_params_dev.yaml')
else if std.extVar('env_name')=='preprod' then std.parseYaml(importstr '../argo_params_preprod.yaml')
else if std.extVar('env_name')=='prod' then std.parseYaml(importstr '../argo_params_prod.yaml')
else if std.extVar('env_name')=='test' then std.parseYaml(importstr '../argo_params_test.yaml')
else {};
local env = std.parseYaml(importstr '../env.yaml')[terraform_config.env_name];


local ignoreDifferencesDefault = [
  {
    group: 'apiextensions.k8s.io',
    kind: 'CustomResourceDefinition',
    jsonPointers: [
        '/spec/preserveUnknownFields'
    ]
  },
  {
    group: 'datadoghq.com',
    kind: 'DatadogMonitor',
    jsonPointers: [
      '/spec/tags',
    ],
  },
  {
    group: 'v1',
    kind: 'Service',
    jqPathExpressions:[
      '.spec.selector["rollouts-pod-template-hash"]'
    ]
  },
  {
    group: 'gateway.networking.k8s.io/v1',
    kind: 'HTTPRoute',
    jqPathExpressions:[
      '.spec.rules[*].weight | select(.metadata.annotations."rollouts" == "true")'
    ]
  },
  {
    kind: 'Pod',
    jqPathExpressions: ['.metadata.annotations.reloader["stakater.com/last-reloaded-from"]'],
  },
]
+
[
  {
    kind: kind,
    jqPathExpressions: ['.spec.template.metadata.annotations["stakater.com/last-reloaded-from"]'],
  }
  for kind in ['Deployment', 'StatefulSet', 'ReplicaSet', 'DaemonSet']
];

{
  local parent_config = std.parseJson(std.extVar('config')),
  local _config = std.mergePatch( terraform_config + { env: env }, parent_config),
  config:: _config,
  revisions:: std.parseYaml(importstr '../revisions.yaml'),

  local _app(
    name,
    dest_namespace,
    path,
    project='default',
    vars=null,
    dest_k8s='https://kubernetes.default.svc',
    namespace='argo',
    annotations={},
    update_image=null,
    wave=null,
    createNamespace=true,
    replace=false,
    applyOutOfSyncOnly=false,
    skipDryRun=false,
    skipCrds=null,
    helm_params=null,
    ignoreDifferences=[],
    syncLimit=7,
    config={},
    istio=false,
    labels=null,
    repo=null,
    targetRevision=null
  ) = {
      apiVersion: 'argoproj.io/v1alpha1',
      kind: 'Application',
      metadata: {
        name: name,
        namespace: namespace,
        finalizers: [
          'resources-finalizer.argocd.argoproj.io',
        ],
        [if annotations!={} || update_image!=null || wave!=null then 'annotations']: annotations + (if update_image != null then {
          'argocd-image-updater.argoproj.io/image-list': 'imageAliace=' + update_image + ':latest',
          'argocd-image-updater.argoproj.io/imageAliace.update-strategy': 'digest',
        } else {}) + if wave != null then { 'argocd.argoproj.io/sync-wave': std.toString(wave) } else {},
        [if labels != null then 'labels']: labels,
      },
      spec: {
        project: project,
        source: {
          repoURL: if repo == null then _config.argo_repo else repo,
          targetRevision: if targetRevision == null then _config.argo_branch else targetRevision,
          path: path,
          [if helm_params != null || skipCrds != null then 'helm']: {
            [if helm_params != null then 'parameters']: helm_params,
            [if skipCrds != null then 'skipCrds']: skipCrds,
          },
        } + {
          directory: {
            jsonnet: {
              extVars: [
                {
                  name: 'env_name',
                  value: terraform_config.env_name,
                },
                {
                  name: 'config',
                  value: std.toString(config+{app_name: name}),
                },
              ] + if vars != null then vars else [],
            },
          },
        },
        destination: {
          server: dest_k8s,
          namespace: dest_namespace,
        },
        syncPolicy: {
          [if istio then 'managedNamespaceMetadata']: {
            labels: {
              'istio-injection': 'enabled',
            },
          },
          automated: {
            prune: true,
            selfHeal: true,
          },
          syncOptions: [
            'RespectIgnoreDifferences=true',
            'ApplyOutOfSyncOnly=true',
            'CreateNamespace=' + createNamespace,
            'ServerSideApply=true',
          ]
          + if replace then ['Replace=true'] else []
          + if applyOutOfSyncOnly then ['ApplyOutOfSyncOnly=true'] else []
          + if skipDryRun then ['SkipDryRunOnMissingResource=true'] else [],
          retry: {
            limit: syncLimit,
            backoff: {
              duration: '5s',
              factor: 2,
              maxDuration: '3m',
            },
          },
        },
        ignoreDifferences: ignoreDifferencesDefault + ignoreDifferences,
      },
    },
  app:: _app,

  local _appKustomize(
    name,
    dest_namespace,
    git,
    path,
    project='default',
    dest_k8s='https://kubernetes.default.svc',
    namespace='argo',
    annotations={},
    update_image=null,
    wave=null,
    createNamespace=true,
    replace=false,
    applyOutOfSyncOnly=false,
    skipDryRun=false,
    skipCrds=null,
    helm_params=null,
    ignoreDifferences=[],
    targetRevision='master'
  ) = {
      apiVersion: 'argoproj.io/v1alpha1',
      kind: 'Application',
      metadata: {
        name: name,
        namespace: namespace,
        finalizers: [
          'resources-finalizer.argocd.argoproj.io',
        ],
        [if annotations!={} || update_image!=null || wave!=null then 'annotations']: annotations + (if update_image != null then {
          'argocd-image-updater.argoproj.io/image-list': 'imageAliace=' + update_image + ':latest',
          'argocd-image-updater.argoproj.io/imageAliace.update-strategy': 'digest',
        } else {}) + if wave != null then { 'argocd.argoproj.io/sync-wave': std.toString(wave) } else {},
      },
      spec: {
        project: project,
        source: {
          repoURL: git,
          targetRevision: targetRevision,
          path: path,
          [if helm_params != null || skipCrds != null then 'helm']: {
            [if helm_params != null then 'parameters']: helm_params,
            [if skipCrds != null then 'skipCrds']: skipCrds,
          },
        },
        destination: {
          server: dest_k8s,
          namespace: dest_namespace,
        },
        syncPolicy: {
          automated: {
            prune: true,
            selfHeal: true,
          },
          syncOptions: [
            'RespectIgnoreDifferences=true',
            'ApplyOutOfSyncOnly=true',
            'ServerSideApply=true',
            'CreateNamespace=' + createNamespace,
          ]
          + if replace then ['Replace=true'] else []
          + if applyOutOfSyncOnly then ['ApplyOutOfSyncOnly=true'] else []
          + if skipDryRun then ['SkipDryRunOnMissingResource=true'] else [],
          retry: {
            limit: -1,
            backoff: {
              duration: '5s',
              factor: 2,
              maxDuration: '3m',
            },
          },
        },
        ignoreDifferences: ignoreDifferencesDefault + ignoreDifferences,
      },
    },
  appKustomize:: _appKustomize,

  app_helm(name,
    dest_namespace,
    repo,
    chart,
    targetRevision,
    path=null,
    helm_params=null,
    values=null,
    valuesObject=null,
    project='default',
    dest_k8s='https://kubernetes.default.svc',
    namespace='argo',
    annotations={},
    wave=null,
    selfHeal=true,
    ignoreDifferences=[],
    createNamespace=true,
    skipCrds=null,
    skipDryRun=false,
    replace=false):: {
      apiVersion: 'argoproj.io/v1alpha1',
      kind: 'Application',
      metadata: {
        name: name,
        namespace: namespace,
        finalizers: [
          'resources-finalizer.argocd.argoproj.io',
        ],
        [if annotations!={} || wave!=null then 'annotations']: annotations +
        if wave != null then { 'argocd.argoproj.io/sync-wave': std.toString(wave) } else {},
      },
      spec: {
        project: project,
        source: {
          repoURL: repo,
          targetRevision: targetRevision,
          [if path != null then 'path']: path,
          [if chart != null then 'chart']: chart,
          [if helm_params != null || values != null || skipCrds != null || valuesObject != null then 'helm']: {
            [if helm_params != null then 'parameters']: helm_params,
            [if skipCrds != null then 'skipCrds']: skipCrds,
            [if values != null then 'values']: values,
            [if valuesObject != null then 'valuesObject']: valuesObject,
          },
        },
        destination: {
          server: dest_k8s,
          namespace: dest_namespace,
        },
        syncPolicy: {
          automated: {
            prune: true,
            selfHeal: selfHeal,
          },
          syncOptions: [
            'RespectIgnoreDifferences=true',
            'ApplyOutOfSyncOnly=true',
            'CreateNamespace=' + createNamespace,
            'ServerSideApply=true',
          ]
          + if skipDryRun then ['SkipDryRunOnMissingResource=true'] else []
          + if replace then ['Replace=true'] else [],
          retry: {
            limit: -1,
            backoff: {
              duration: '5s',
              factor: 2,
              maxDuration: '3m',
            },
          },
        },
        ignoreDifferences: ignoreDifferencesDefault + ignoreDifferences,
      },
    },


  local parseKubeconfig = function(region, name, configStr) {
    local parsed = std.parseYaml(configStr),

    config: {
      bearerToken: parsed.users[0].user.token,
      tlsClientConfig: {
        caData: parsed.clusters[0].cluster['certificate-authority-data'],
        insecure: false,
      },
    },

    server: parsed.clusters[0].cluster.server,
    name: parsed.users[0].name,
    clusterName: 'eks-' + region + '-' + name,
  },

  local _clusterFromKubeconfig = function(region, name, configStr, environment, wave=null) k8s.secret(
    environment + '-' + parseKubeconfig(region, name, configStr).clusterName,
    stringData={
      name: environment + '-' + parseKubeconfig(region, name, configStr).clusterName,
      server: parseKubeconfig(region, name, configStr).server,
      config: std.toString(parseKubeconfig(region, name, configStr).config),
    },
    wave=wave,
    labels={
      'argocd.argoproj.io/secret-type': 'cluster',
    },
  ),
  clusterFromKubeconfig:: _clusterFromKubeconfig,

  local _var = function(name, value) {
    name: name,
    value: value,
  },
  var:: _var,

  local _extVar = function(name) {
    name: name,
    value: std.extVar(name),
  },
  extVar:: _extVar,
}
