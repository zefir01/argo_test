local argo = import '../libs/argo.libsonnet';

{
  nodeClass:: function(name, security_groups=argo.config.cluster_sg, role=argo.config.cluster_worker_role, cluster_name=argo.config.cluster_name, volumeSize='100Gi', volumeType='gp3', iops=3000, wave=null) {
    apiVersion: 'karpenter.k8s.aws/v1',
    kind: 'EC2NodeClass',
    metadata: {
      name: name,
      annotations: {
        'argocd.argoproj.io/sync-options': 'Replace=true',
        [if wave != null then 'argocd.argoproj.io/sync-wave']: std.toString(wave),
      },
    },
    spec: {
      kubelet: {
        maxPods: 110,
        systemReserved: {
          cpu: '300m',
          memory: '256Mi',
          'ephemeral-storage': '1Gi',
        },
        kubeReserved: {
          cpu: '300m',
          memory: '256Mi',
          'ephemeral-storage': '3Gi',
        },
      },
      amiSelectorTerms: [
        {
          alias: 'al2023@latest',
        },
      ],
      subnetSelectorTerms: [
        {
          tags: {
            ['kubernetes.io/cluster/' + argo.config.cluster_name]: '*',
            type: 'private',
          },
        },
      ],
      securityGroupSelectorTerms: [
        {
          tags: {
            ['kubernetes.io/cluster/' + argo.config.cluster_name]: 'owned',
            Name: argo.config.cluster_name + '-node',
          },
        },
      ],
      role: role,
      metadataOptions: {
        httpEndpoint: 'enabled',
        httpProtocolIPv6: 'disabled',
        httpPutResponseHopLimit: 64,
        httpTokens: 'optional',
      },
      blockDeviceMappings: [
        {
          deviceName: '/dev/xvda',
          ebs: {
            volumeSize: volumeSize,
            volumeType: volumeType,
            iops: iops,
            encrypted: true,
            deleteOnTermination: true,
          },
        },
      ],
      detailedMonitoring: false,
    },
  },

  nodePool:: function(
    name,
    instance_category=['t', 'c', 'm', 'r'],
    instance_generation=['2'],
    cpu=80,
    memory='500Gi',
    spot=true,
    disruptionNodes=1,
    lifetime='720h',
    taints=null,
    nodeClass='default',
    doNotDisrupt=false,
    arch='amd64',
    hypervisor='nitro',
    weight=100,
    wave=null
            ) {
    apiVersion: 'karpenter.sh/v1',
    kind: 'NodePool',
    metadata: {
      name: name,
    },
    spec: {
      weight: weight,
      template: {
        metadata: {
          [if doNotDisrupt || wave != null then 'annotations']: {
            [if doNotDisrupt then 'karpenter.sh/do-not-disrupt']: 'true',
            [if wave != null then 'argocd.argoproj.io/sync-wave']: std.toString(wave),
          },
          labels: {
            karpenter_pool_name: name,
          },
        },
        spec: {
          expireAfter: lifetime,
          nodeClassRef: {
            name: nodeClass,
            kind: 'EC2NodeClass',
            group: 'karpenter.k8s.aws',
          },
          [if taints != null then 'taints']: taints,
          requirements:
            (if hypervisor == null then [] else [
               {
                 key: 'karpenter.k8s.aws/instance-hypervisor',
                 operator: 'In',
                 values: [
                   hypervisor,
                 ],
               },
             ])
            +
            [
              {
                key: 'karpenter.k8s.aws/instance-category',
                operator: 'In',
                values: instance_category,
              },
              {
                key: 'karpenter.k8s.aws/instance-generation',
                operator: 'Gt',
                values: instance_generation,
              },
              {
                key: 'kubernetes.io/arch',
                operator: 'In',
                values: [
                  arch,
                ],
              },
              {
                key: 'karpenter.sh/capacity-type',
                operator: 'In',
                values: (if spot then ['spot'] else []) + ['on-demand'],
              },
              {
                key: 'kubernetes.io/os',
                operator: 'In',
                values: [
                  'linux',
                ],
              },
            ],
        },
      },
      disruption: {
        consolidationPolicy: 'WhenEmptyOrUnderutilized',
        consolidateAfter: '1m',
        budgets: [
          {
            nodes: std.toString(disruptionNodes),
          },
        ],
      },
      limits: {
        cpu: std.toString(cpu),
        memory: std.toString(memory),
      },
    },
  },
}
