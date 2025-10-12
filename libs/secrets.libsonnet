local secrets = std.parseYaml(importstr '../secrets.yaml');
local argo = import '../libs/argo.libsonnet';

{
  local _getSealedSecret = function(name, object=null, wave=null) std.mergePatch(
    if object != null then object else secrets[argo.config.env_name][name],
    if wave == null then {} else {
      metadata: {
        annotations: {
          'argocd.argoproj.io/sync-wave': std.toString(wave),
        },
      },
    }
  ),
  getSealedSecret:: _getSealedSecret,

  local _getSealedSecretClusterwide = function(name, srcName, namespace, object=null, wave=null)
    std.mergePatch(
      if object != null then object else secrets[argo.config.env_name][srcName],
      {
        metadata: {
          namespace: namespace,
          name: name,
          annotations: {
            'argocd.argoproj.io/sync-wave': std.toString(wave),
          },
        },
        spec: {
          template: {
            metadata: {
              namespace: namespace,
              name: name,
            },
          },
        },
      }
    ),
  getSealedSecretClusterwide:: _getSealedSecretClusterwide,

  local get = function(obj, name) if obj == null then std.get(secrets, name) else std.get(obj, name),
  local _getSecretByPath = function(path) std.foldl(get, [argo.config.env_name] + std.split(path, '.'), null),
  local _getSealedSecretClusterwideByPath = function(name, path, namespace, wave=null) _getSealedSecretClusterwide(name, null, namespace, object=_getSecretByPath(path), wave=wave),
  local _getSealedSecretByPath = function(name, path, wave=null) _getSealedSecret(name, object=_getSecretByPath(path), wave=wave),
  getSealedSecretByPath:: _getSealedSecretByPath,
  getSealedSecretClusterwideByPath:: _getSealedSecretClusterwideByPath,
}
