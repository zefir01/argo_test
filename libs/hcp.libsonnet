local argo = import '../libs/argo.libsonnet';
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
        },
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
              resources: k8s.deployment_container_resources('500m', '500Mi', '1', '2Gi'),
            },
          ],
        },
      },
      autoscaling: {
        minReplicas: 0,
        maxReplicas: 10,
        cooldownPeriod: {
          scaleUpSeconds: 1,
          scaleDownSeconds: 30,
        },
      },
    },
  },

  project(name, organization, secretName, secretKey, namespace=null, wave=null):: {
    apiVersion: 'app.terraform.io/v1alpha2',
    kind: 'Project',
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
        },
      },
      name: name,
      deletionPolicy: 'soft',
    },
  },

  workspace(name, organization, project, secretName, secretKey, vars=null, env=null, namespace=null, wave=null):: {
    apiVersion: 'app.terraform.io/v1alpha2',
    kind: 'Workspace',
    metadata: {
      name: name,
      [if wave != null then 'annotations']: {
        'argocd.argoproj.io/sync-wave': std.toString(wave),
        'workspace.app.terraform.io/run-new': 'true',
        'workspace.app.terraform.io/run-type': 'apply',
      },
      [if namespace != null then 'namespace']: namespace,
    },
    spec: {
      organization: organization,
      project: {
        name: project,
      },
      token: {
        secretKeyRef: {
          name: secretName,
          key: secretKey,
        },
      },
      name: name,
      description: 'Kubernetes Operator Automated Workspace',
      applyMethod: 'auto',
      applyRunTrigger: 'auto',
      deletionPolicy: 'destroy',
      terraformVersion: '1.13.2',
      [if vars != null then 'terraformVariables']: vars,
      [if env != null then 'environmentVariables']: env,
      executionMode: 'remote',
      workingDirectory: 'tfc',
      versionControl: {
        branch: argo.config.argo_branch,
        oAuthTokenID: 'ot-4uP6HKAQMqhZGJ5P',
        repository: 'zefir01/argo_test',
        speculativePlans: false,
        //enableFileTriggers: true,
        //triggerPrefixes:['tfc']
      },
      //agentPool: {
      //  name: 'main'
      // }
    },
  },
}
