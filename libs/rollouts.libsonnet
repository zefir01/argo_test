{
  canary(name, containers, canaryService, stableService, replicas=1, labels={}):: {
    apiVersion: 'argoproj.io/v1alpha1',
    kind: 'Rollout',
    metadata: {
      name: name,
    },
    spec: {
      replicas: replicas,
      revisionHistoryLimit: 1,
      selector: {
        matchLabels: labels,
      },
      template: {
        metadata: {
          labels: labels,
        },
        spec: {
          containers: containers,
        },
      },
      strategy: {
        canary: {
          canaryService: canaryService,
          stableService: stableService,
          steps: [
            {
              setWeight: 20,
            },
            {
              pause: {},
            },
            {
              setWeight: 40,
            },
            {
              pause: {
                duration: 10,
              },
            },
            {
              setWeight: 60,
            },
            {
              pause: {
                duration: 10,
              },
            },
            {
              setWeight: 80,
            },
            {
              pause: {
                duration: 10,
              },
            },
          ],
        },
      },
    },
  },
}
