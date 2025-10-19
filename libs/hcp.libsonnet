{
  pool(name, organization, secretName, secretKey):: {
    apiVersion: 'app.terraform.io/v1alpha2',
    kind: 'AgentPool',
    metadata: {
      name: name,
    },
    spec: {
      organization: organization,
      token: {
        secretKeyRef: null,
        name: secretName,
        key: secretKey,
      },
      name: name,
      agentTokens: [
        {
          name: 'agent-pool-dev-token',
        },
      ],
      agentDeployment: {
        replicas: 1,
        spec: null,
        containers: [
          {
            name: 'tfc-agent',
            image: 'hashicorp/tfc-agent:1.13.1',
          },
        ],
      },
    },
  },
}
