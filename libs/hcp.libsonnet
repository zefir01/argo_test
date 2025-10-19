local k8s = import '../libs/k8s.libsonnet';

{
  pool(name, organization, secretName, secretKey, namespace=null, wave=null):: {
    apiVersion: 'app.terraform.io/v1alpha2',
    kind: 'AgentPool',
    metadata: {
      name: name,
      [if wave != null then 'annotations']: {
        'argocd.argoproj.io/sync-wave': std.toString(wave),
      },
      [if namespace != null then 'namespace']: namespace,
    },
    spec: {
      organization: organization,
      token: {
        secretKeyRef: {
          name: secretName,
          key: secretKey,
        }
      },
      name: name,
      agentTokens: [
        {
          name: 'agent-pool-dev-token',
        },
      ],
      agentDeployment: {
        replicas: 1,
        spec: {
          serviceAccountName: 'hcp-agent',
          containers: [
              {
                name: 'tfc-agent',
                image: 'hashicorp/tfc-agent:1.13.1',
                resources: k8s.deployment_container_resources('500m', '500Mi', '1', '2Gi')
              },
            ],
        }
      },
      autoscaling:{
        minReplicas: 0,
        maxReplicas: 10,
        cooldownPeriod:{
          scaleUpSeconds: 1,
          scaleDownSeconds: 30
        }
      }
    },
  },
}
