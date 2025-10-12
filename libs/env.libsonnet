local argo = import '../libs/argo.libsonnet';

{

  local makeArray = function(value) if std.isArray(value) then value else [value],
  local _isDev = function() argo.config.env_name == 'dev',
  isDev:: _isDev,
  local _isPreprod = function() argo.config.env_name == 'demo',
  isPreprod:: _isPreprod,
  local _isProd = function() argo.config.env_name == 'prod',
  isProd:: _isProd,
  local _isNotDev = function() argo.config.env_name != 'dev',
  isNotDev:: _isNotDev,
  local _isSnd = function() argo.config.env_name == 'snd',
  isSnd:: _isSnd,
  local _isTest = function() argo.config.env_name == 'test',
  isTest:: _isTest,

  local _toTest = function(value) if _isTest() then makeArray(value) else [],
  toTest:: _toTest,

  local _toSnd = function(value) if _isSnd() then makeArray(value) else [],
  toSnd:: _toSnd,

  local _toDev = function(value) if _isDev() then makeArray(value) else [],
  toDev:: _toDev,

  local _notDev = function(value) if !_isDev() then makeArray(value) else [],
  notDev:: _notDev,

  local _toPreprod = function(value) if _isPreprod() then makeArray(value) else [],
  toPreprod:: _toPreprod,

  local _notPreprod = function(value) if !_isPreprod() then makeArray(value) else [],
  notPreprod:: _notPreprod,


  local _toProd = function(value) if _isProd() then makeArray(value) else [],
  toProd:: _toProd,

  local _notProd = function(value) if !_isProd() then makeArray(value) else [],
  notProd:: _notProd,
}
