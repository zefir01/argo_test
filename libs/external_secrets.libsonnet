local argo = import 'argo.libsonnet';

{
  clusterStore(name, saName='external-secrets-store', wave=null):: {
    apiVersion: 'external-secrets.io/v1beta1',
    kind: 'ClusterSecretStore',
    metadata: {
      name: name,
      [if wave != null then 'annotations']: {
        'argocd.argoproj.io/sync-wave': std.toString(wave),
      },
    },
    spec: {
      provider: {
        aws: {
          service: 'SecretsManager',
          region: argo.config.region,
          auth: {
            jwt: {
              serviceAccountRef: {
                name: saName,
                namespace: 'kube-system',
              },
            },
          },
        },
      },
    },
  },
  externalSecret(
    name,
    secretName,
    secretStoreRef={
      kind: 'ClusterSecretStore',
      name: 'main',
    },
    decodingStrategy='Auto',
    labels=null,
    namespace=null,
    wave=null
  ):: {
    apiVersion: 'external-secrets.io/v1beta1',
    kind: 'ExternalSecret',
    metadata: {
      name: name,
      [if namespace != null then 'namespace']: namespace,
      [if wave != null then 'annotations']: {
        'argocd.argoproj.io/sync-wave': std.toString(wave),
      },
    },
    spec: {
      refreshInterval: '3m',
      secretStoreRef: secretStoreRef,
      target: {
        name: name,
        creationPolicy: 'Owner',
        [if labels != null then 'template']: {
          metadata: {
            labels: labels,
          },
        },
      },
      dataFrom: [
        {
          extract: {
            conversionStrategy: 'Default',
            decodingStrategy: decodingStrategy,
            metadataPolicy: 'None',
            key: secretName,
          },
        },
      ],
    },
  },

  externalDockerconfig(
    name,
    secretName,
    secretStoreRef={
      kind: 'ClusterSecretStore',
      name: 'local',
    },
    decodingStrategy='Auto',
    namespace=null,
    wave=null
  ):: {
    apiVersion: 'external-secrets.io/v1beta1',
    kind: 'ExternalSecret',
    metadata: {
      name: name,
      [if namespace != null then 'namespace']: namespace,
      [if wave != null then 'annotations']: {
        'argocd.argoproj.io/sync-wave': std.toString(wave),
      },
    },
    spec: {
      refreshInterval: '3m',
      secretStoreRef: secretStoreRef,
      target: {
        name: name,
        template: {
          type: 'kubernetes.io/dockerconfigjson',
        },
        creationPolicy: 'Owner',
      },
      dataFrom: [
        {
          extract: {
            conversionStrategy: 'Default',
            decodingStrategy: decodingStrategy,
            metadataPolicy: 'None',
            key: secretName,
          },
        },
      ],
    },
  },
}
