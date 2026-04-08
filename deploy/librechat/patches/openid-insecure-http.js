const Module = require('module');

const originalLoad = Module._load;

function wrapOpenIdClient(client) {
  if (
    !client ||
    typeof client.discovery !== 'function' ||
    typeof client.allowInsecureRequests !== 'function'
  ) {
    return client;
  }

  if (client.__teamAiPatchedOpenIdClient === true) {
    return client;
  }

  return new Proxy(client, {
    get(target, prop, receiver) {
      if (prop === '__teamAiPatchedOpenIdClient') {
        return true;
      }

      if (prop === 'discovery') {
        return async function patchedDiscovery(
          server,
          clientId,
          clientMetadata,
          clientAuthentication,
          options,
        ) {
          const issuer = server instanceof URL ? server : new URL(server);
          const allowInsecureHttp = process.env.OPENID_ALLOW_INSECURE_HTTP === 'true';
          const execute = Array.isArray(options?.execute) ? [...options.execute] : [];

          if (
            allowInsecureHttp &&
            issuer.protocol === 'http:' &&
            !execute.includes(target.allowInsecureRequests)
          ) {
            execute.push(target.allowInsecureRequests);
          }

          return target.discovery(server, clientId, clientMetadata, clientAuthentication, {
            ...(options ?? {}),
            execute,
          });
        };
      }

      return Reflect.get(target, prop, receiver);
    },
  });
}

Module._load = function patchedModuleLoad(request, parent, isMain) {
  const loaded = originalLoad.apply(this, [request, parent, isMain]);

  if (request === 'openid-client' || request === '/app/api/node_modules/openid-client') {
    return wrapOpenIdClient(loaded);
  }

  return loaded;
};
