const Module = require('module');
const cookie = require('cookie');

const originalLoad = Module._load;
const OPENID_STATE_VERIFICATION_ERROR = 'Unable to verify authorization request state';
const SYNTHETIC_EMAIL_DOMAIN = 'casdoor.team-ai.local';

function escapeForInlineScript(value) {
  return String(value)
    .replace(/\\/g, '\\\\')
    .replace(/'/g, "\\'")
    .replace(/</g, '\\x3C');
}

function getDomainClientPath() {
  try {
    const clientUrl = new URL(process.env.DOMAIN_CLIENT || '');
    if (clientUrl.pathname === '/') {
      return '';
    }
    return clientUrl.pathname.replace(/\/+$/, '');
  } catch {
    return '';
  }
}

function getServerDomain() {
  return String(process.env.DOMAIN_SERVER || process.env.DOMAIN_CLIENT || '').replace(/\/+$/, '');
}

function getRequestOrigin(req) {
  if (getServerDomain()) {
    return getServerDomain();
  }

  const protocol = req?.protocol || 'http';
  const host = typeof req?.get === 'function' ? req.get('host') : req?.headers?.host;
  return host ? `${protocol}://${host}` : '';
}

function isOpenIdCallbackRequest(req) {
  const requestPath = String(req?.originalUrl || req?.url || req?.path || '').split('?')[0];
  return requestPath.endsWith('/oauth/openid/callback') || requestPath.endsWith('/openid/callback');
}

function getRedirectPath(redirectUrl, req) {
  if (typeof redirectUrl !== 'string' || !redirectUrl) {
    return '';
  }

  try {
    const baseUrl = getRequestOrigin(req) || 'http://localhost';
    return new URL(redirectUrl, baseUrl).pathname.replace(/\/+$/, '') || '/';
  } catch {
    return '';
  }
}

function isOpenIdStartRedirect(redirectUrl, req) {
  return getRedirectPath(redirectUrl, req).endsWith('/oauth/openid');
}

function isOAuthErrorRedirect(redirectUrl, req) {
  return getRedirectPath(redirectUrl, req).endsWith('/oauth/error');
}

function isOpenIdStateVerificationError(err) {
  return String(err?.message || err || '').includes(OPENID_STATE_VERIFICATION_ERROR);
}

function retryOpenIdAfterLostState(req, err) {
  if (!isOpenIdCallbackRequest(req) || !isOpenIdStateVerificationError(err)) {
    return false;
  }

  if (!req?.res || typeof req.res.redirect !== 'function') {
    return false;
  }

  if (req.session?.teamAiOpenIdStateRetry) {
    console.warn('[TeamAI OpenID Patch] OpenID state recovery already attempted for this session');
    return false;
  }

  req.session = req.session || {};
  req.session.teamAiOpenIdStateRetry = true;
  req.session.messages = [];

  const serverDomain = getRequestOrigin(req);
  const retryUrl = serverDomain ? `${serverDomain}/oauth/openid` : '/oauth/openid';

  console.warn('[TeamAI OpenID Patch] Recovering missing OpenID state with a fresh auth request', {
    sessionId: req.sessionID,
    retryUrl,
  });

  req.res.redirect(retryUrl);
  return true;
}

function buildPlatformBootstrapScript() {
  const serverDomain = String(process.env.DOMAIN_SERVER || process.env.DOMAIN_CLIENT || '').replace(
    /\/+$/,
    '',
  );
  const loginPath = `${getDomainClientPath()}/login` || '/login';
  const themeMode = ['dark', 'light', 'system'].includes(process.env.PLATFORM_THEME_MODE)
    ? process.env.PLATFORM_THEME_MODE
    : 'dark';
  const themeLock = process.env.PLATFORM_THEME_LOCK !== 'false';
  const hideThemeSelector = process.env.PLATFORM_HIDE_THEME_SELECTOR !== 'false';
  const shouldAutoRedirect = process.env.OPENID_AUTO_REDIRECT === 'true' && !!serverDomain;
  const oauthTarget = shouldAutoRedirect ? `${serverDomain}/oauth/openid` : '';
  const platformCss = [
    ':root { color-scheme: dark light; }',
    '@media (prefers-color-scheme: dark) { html, body { background: #0d0d0d !important; } }',
    '@media (prefers-color-scheme: light) { html, body { background: #ffffff !important; } }',
    hideThemeSelector ? '[aria-keyshortcuts="Ctrl+Shift+T"] { display: none !important; }' : '',
    hideThemeSelector ? '#theme-selector-label { display: none !important; }' : '',
    hideThemeSelector ? '[aria-labelledby="theme-selector-label"] { display: none !important; }' : '',
  ]
    .filter(Boolean)
    .join('\n');

  return [
    '<script id="team-ai-platform-bootstrap">',
    '(function(){',
    'try{',
    `var lockedTheme=${JSON.stringify(themeMode)};`,
    `var themeLock=${themeLock};`,
    `var hideThemeSelector=${hideThemeSelector};`,
    `var shouldAutoRedirect=${shouldAutoRedirect};`,
    `var loginPath=${JSON.stringify(loginPath)};`,
    `var oauthTarget=${JSON.stringify(oauthTarget)};`,
    `var platformCss=${JSON.stringify(platformCss)};`,
    'if(themeLock && lockedTheme){',
    '  try {',
    '    localStorage.setItem("color-theme", lockedTheme);',
    '    window.__TEAMAI_THEME_LOCK__ = lockedTheme;',
    '  } catch (storageError) {',
    '    console.error("[TeamAI Theme Patch] Failed to persist locked theme", storageError);',
    '  }',
    '  if(typeof Storage !== "undefined" && Storage.prototype && !window.__TEAMAI_STORAGE_PATCHED__){',
    '    window.__TEAMAI_STORAGE_PATCHED__ = true;',
    '    var originalSetItem = Storage.prototype.setItem;',
    '    Storage.prototype.setItem = function(key, value){',
    '      if(key === "color-theme"){',
    '        return originalSetItem.call(this, key, lockedTheme);',
    '      }',
    '      return originalSetItem.call(this, key, value);',
    '    };',
    '  }',
    '}',
    'if(platformCss && !document.getElementById("team-ai-platform-style")){',
    '  var style=document.createElement("style");',
    '  style.id="team-ai-platform-style";',
    '  style.textContent=platformCss;',
    '  document.head.appendChild(style);',
    '}',
    'var hideThemeControls = function(){',
    '  if(!hideThemeSelector){ return; }',
    '  document.querySelectorAll("[aria-keyshortcuts=\\"Ctrl+Shift+T\\"]").forEach(function(node){',
    '    node.style.display="none";',
    '    if(node.parentElement && node.parentElement.childElementCount === 1){',
    '      node.parentElement.style.display="none";',
    '    }',
    '  });',
    '  document.querySelectorAll("[aria-labelledby=\\"theme-selector-label\\"]").forEach(function(node){',
    '    var row = node.closest("div.flex.items-center.justify-between");',
    '    if(row && row.parentElement){',
    '      row.parentElement.style.display="none";',
    '      return;',
    '    }',
    '    node.style.display="none";',
    '  });',
    '  var label = document.getElementById("theme-selector-label");',
    '  if(label){',
    '    var labelRow = label.closest("div.flex.items-center.justify-between");',
    '    if(labelRow && labelRow.parentElement){',
    '      labelRow.parentElement.style.display="none";',
    '    } else {',
    '      label.style.display="none";',
    '    }',
    '  }',
    '};',
    'hideThemeControls();',
    'if(hideThemeSelector && typeof MutationObserver !== "undefined"){',
    '  var observer = new MutationObserver(hideThemeControls);',
    '  observer.observe(document.documentElement, { childList: true, subtree: true });',
    '}',
    'document.addEventListener("click", function(event){',
    '  if(!themeLock){ return; }',
    '  var target = event.target && event.target.closest ? event.target.closest("[aria-keyshortcuts=\\"Ctrl+Shift+T\\"]") : null;',
    '  if(target){',
    '    event.preventDefault();',
    '    event.stopImmediatePropagation();',
    '  }',
    '}, true);',
    'window.addEventListener("keydown", function(event){',
    '  if(!themeLock){ return; }',
    '  if(event.ctrlKey && event.shiftKey && String(event.key || "").toLowerCase() === "t"){',
    '    event.preventDefault();',
    '    event.stopImmediatePropagation();',
    '  }',
    '}, true);',
    "var currentPath=(window.location.pathname||'/').replace(/\\/+$/,'')||'/';",
    'var params=new URLSearchParams(window.location.search||"");',
    'if(shouldAutoRedirect && currentPath===loginPath && !params.toString()){',
    '  window.location.replace(oauthTarget);',
    '}',
    '}catch(error){',
    'console.error("[TeamAI Platform Patch] Bootstrap failed", error);',
    '}',
    '})();',
    '</script>',
  ].join('');
}

function patchFs(fsModule) {
  if (!fsModule || typeof fsModule.readFileSync !== 'function' || fsModule.__teamAiPatchedFs === true) {
    return fsModule;
  }

  const originalReadFileSync = fsModule.readFileSync;
  const bootstrapScript = buildPlatformBootstrapScript();

  fsModule.readFileSync = function patchedReadFileSync(filePath, options) {
    const content = originalReadFileSync.apply(this, [filePath, options]);

    if (!bootstrapScript) {
      return content;
    }

    const resolvedPath =
      typeof filePath === 'string' ? filePath : Buffer.isBuffer(filePath) ? filePath.toString('utf8') : '';

    if (!resolvedPath.endsWith('/app/client/dist/index.html')) {
      return content;
    }

    const html = Buffer.isBuffer(content) ? content.toString('utf8') : content;
    if (typeof html !== 'string' || html.includes('team-ai-platform-bootstrap')) {
      return content;
    }

    const themeScriptMarker = "<script>\n      const theme = localStorage.getItem('color-theme');";
    const patchedHtml = html.includes(themeScriptMarker)
      ? html.replace(themeScriptMarker, `${bootstrapScript}${themeScriptMarker}`)
      : html.replace('</head>', `${bootstrapScript}</head>`);

    if (patchedHtml === html) {
      return content;
    }

    console.info('[TeamAI Platform Patch] Injected theme lock and auth bootstrap into index.html');
    return Buffer.isBuffer(content) ? Buffer.from(patchedHtml, 'utf8') : patchedHtml;
  };

  Object.defineProperty(fsModule, '__teamAiPatchedFs', {
    value: true,
    enumerable: false,
    configurable: false,
    writable: false,
  });

  return fsModule;
}

function patchLibreChatApi(api) {
  if (!api || typeof api.findOpenIDUser !== 'function' || api.__teamAiPatchedApi === true) {
    return api;
  }

  const originalFindOpenIDUser = api.findOpenIDUser;

  api.findOpenIDUser = async function patchedFindOpenIDUser(args) {
    const allowLocalAccountLinking = process.env.OPENID_ALLOW_LOCAL_ACCOUNT_LINKING === 'true';

    if (!allowLocalAccountLinking || !args?.email || typeof args?.findUser !== 'function') {
      return originalFindOpenIDUser(args);
    }

    const result = await originalFindOpenIDUser(args);
    if (result?.user || !result?.error) {
      return result;
    }

    const user = await args.findUser({ email: args.email });
    if (!user || !user.provider || user.provider === 'openid') {
      return result;
    }

    if (user.openidId && user.openidId !== args.openidId) {
      return result;
    }

    if (user.provider === 'local') {
      console.info(
        `[TeamAI OpenID Patch] Linking local LibreChat account ${user.email} to OpenID subject ${args.openidId}`,
      );
      user.provider = 'openid';
      user.openidId = args.openidId;
      if (args.idOnTheSource) {
        user.idOnTheSource = args.idOnTheSource;
      }
      return { user, error: null, migration: true };
    }

    return result;
  };

  const originalShouldUseSecureCookie = api.shouldUseSecureCookie;
  if (typeof originalShouldUseSecureCookie === 'function') {
    api.shouldUseSecureCookie = function patchedShouldUseSecureCookie() {
      const allowInsecureHttp = process.env.OPENID_ALLOW_INSECURE_HTTP === 'true';
      const domainServer = String(process.env.DOMAIN_SERVER || '');
      if (allowInsecureHttp || domainServer.startsWith('http://')) {
        return false;
      }
      return originalShouldUseSecureCookie();
    };
  }

  Object.defineProperty(api, '__teamAiPatchedApi', {
    value: true,
    enumerable: false,
    configurable: false,
    writable: false,
  });

  return api;
}

function normalizePatchBool(value, defaultValue = false) {
  if (value === undefined || value === null || value === '') {
    return defaultValue;
  }

  return ['1', 'true', 'yes', 'y', 'on'].includes(String(value).trim().toLowerCase());
}

function getDefaultAdminEmail() {
  return String(process.env.LIBRECHAT_DEFAULT_ADMIN_EMAIL || '').trim().toLowerCase();
}

function isValidEmail(value) {
  return /^[^\s@]+@[^\s@]+\.[^\s@]+$/.test(String(value || '').trim());
}

function isSyntheticOpenIdEmail(value) {
  return new RegExp(`^oidc-[a-z0-9-]+@${SYNTHETIC_EMAIL_DOMAIN.replace(/\./g, '\\.')}$`).test(
    String(value || '').trim().toLowerCase(),
  );
}

function decodeJwtPayload(token) {
  if (!token || typeof token !== 'string') {
    return {};
  }

  const parts = token.split('.');
  if (parts.length < 2) {
    return {};
  }

  try {
    const payload = parts[1].replace(/-/g, '+').replace(/_/g, '/');
    const padded = payload.padEnd(payload.length + ((4 - (payload.length % 4)) % 4), '=');
    return JSON.parse(Buffer.from(padded, 'base64').toString('utf8'));
  } catch {
    return {};
  }
}

function getOpenIdClaimsFromRequest(req) {
  const parsedCookies = req?.headers?.cookie ? cookie.parse(req.headers.cookie) : {};
  const authHeader = String(req?.headers?.authorization || '');
  const bearerToken = authHeader.startsWith('Bearer ') ? authHeader.slice(7) : '';
  const sessionTokens = req?.session?.openidTokens || {};
  const userTokens = req?.user?.federatedTokens || {};

  const candidates = [
    userTokens.id_token,
    sessionTokens.idToken,
    parsedCookies.openid_id_token,
    bearerToken,
  ];

  for (const token of candidates) {
    const claims = decodeJwtPayload(token);
    if (claims && typeof claims === 'object' && claims.sub) {
      return claims;
    }
  }

  return {};
}

function getClaimString(claims, keys) {
  for (const key of keys) {
    const value = claims?.[key];
    if (typeof value === 'string' && value.trim()) {
      return value.trim();
    }
  }

  return '';
}

function getOpenIdDisplayIdentifier(userData, req) {
  const email = String(userData?.email || '').trim();
  if (!isSyntheticOpenIdEmail(email)) {
    return email;
  }

  const claims = getOpenIdClaimsFromRequest(req);
  const phone = getClaimString(claims, ['phone', 'phone_number', 'mobile']);
  if (phone) {
    return phone;
  }

  const claimEmail = getClaimString(claims, ['email', 'preferred_username', 'upn']);
  if (isValidEmail(claimEmail) && !isSyntheticOpenIdEmail(claimEmail)) {
    return claimEmail;
  }

  return (
    getClaimString(claims, ['displayName', 'name', 'username']) ||
    String(userData?.name || userData?.username || userData?.openidId || email).trim()
  );
}

function applyDisplayUserInfo(userData, req) {
  if (!userData || typeof userData !== 'object' || !isSyntheticOpenIdEmail(userData.email)) {
    return userData;
  }

  const displayIdentifier = getOpenIdDisplayIdentifier(userData, req);
  if (!displayIdentifier || displayIdentifier === userData.email) {
    return userData;
  }

  return {
    ...userData,
    email: displayIdentifier,
    teamAiInternalEmail: userData.email,
    teamAiDisplayIdentifier: displayIdentifier,
    teamAiLoginType: isValidEmail(displayIdentifier) ? 'email' : 'phone',
  };
}

function normalizeEmailLocalPart(value) {
  const normalized = String(value || '')
    .trim()
    .toLowerCase()
    .replace(/[^a-z0-9]+/g, '-')
    .replace(/^-+|-+$/g, '');

  return normalized || 'user';
}

function buildSyntheticOpenIdEmail(data) {
  const source =
    data?.openidId ||
    data?.idOnTheSource ||
    data?.username ||
    data?.email ||
    data?.name ||
    'user';

  return `oidc-${normalizeEmailLocalPart(source)}@${SYNTHETIC_EMAIL_DOMAIN}`;
}

function normalizeOpenIdUserEmail(data) {
  if (!data || data.provider !== 'openid') {
    return data;
  }

  if (isValidEmail(data.email)) {
    return data;
  }

  const syntheticEmail = buildSyntheticOpenIdEmail(data);
  console.warn('[TeamAI OpenID Patch] Replacing invalid OpenID email with synthetic email', {
    openidId: data.openidId,
    username: data.username,
    originalEmail: data.email,
    syntheticEmail,
  });

  data.email = syntheticEmail;
  data.emailVerified = true;
  return data;
}

async function shouldPromoteFirstRegisteredUser(models, data) {
  if (!normalizePatchBool(process.env.LIBRECHAT_FIRST_USER_ADMIN_ENABLED, true)) {
    return false;
  }

  if (!data || typeof models?.countUsers !== 'function') {
    return false;
  }

  const email = String(data.email || '').trim().toLowerCase();
  if (!email || email === getDefaultAdminEmail()) {
    return false;
  }

  const role = String(data.role || '').trim().toUpperCase();
  if (role && role !== 'USER') {
    return false;
  }

  const firstUserFilter = { provider: { $ne: 'anonymous' } };
  const defaultAdminEmail = getDefaultAdminEmail();
  if (defaultAdminEmail) {
    firstUserFilter.email = { $ne: defaultAdminEmail };
  }

  const existingHumanUsers = await models.countUsers(firstUserFilter);
  return existingHumanUsers === 0;
}

function patchModels(models) {
  if (!models || typeof models.createUser !== 'function' || models.__teamAiPatchedModels === true) {
    return models;
  }

  const originalCreateUser = models.createUser;
  const originalUpdateUser = models.updateUser;

  models.createUser = async function patchedCreateUser(data, ...args) {
    let userData = normalizeOpenIdUserEmail(data);

    if (await shouldPromoteFirstRegisteredUser(models, userData)) {
      userData = normalizeOpenIdUserEmail({ ...userData, role: 'ADMIN' });
      console.info(
        `[TeamAI LibreChat Admin Patch] Promoting first registered user to ADMIN: ${userData.email}`,
      );
    }

    return originalCreateUser.call(this, userData, ...args);
  };

  if (typeof originalUpdateUser === 'function') {
    models.updateUser = async function patchedUpdateUser(userId, data, ...args) {
      return originalUpdateUser.call(this, userId, normalizeOpenIdUserEmail(data), ...args);
    };
  }

  Object.defineProperty(models, '__teamAiPatchedModels', {
    value: true,
    enumerable: false,
    configurable: false,
    writable: false,
  });

  return models;
}

function patchAuthService(authService) {
  if (
    !authService ||
    typeof authService.setOpenIDAuthTokens !== 'function' ||
    authService.__teamAiPatchedAuthService === true
  ) {
    return authService;
  }

  const originalSetOpenIDAuthTokens = authService.setOpenIDAuthTokens;

  authService.setOpenIDAuthTokens = function patchedSetOpenIDAuthTokens(
    tokenset,
    req,
    res,
    userId,
    existingRefreshToken,
  ) {
    const result = originalSetOpenIDAuthTokens(tokenset, req, res, userId, existingRefreshToken);

    if (!tokenset?.id_token || !res || typeof res.cookie !== 'function') {
      return result;
    }

    const refreshTokenExpiry = Number(process.env.REFRESH_TOKEN_EXPIRY || 604800000);
    const expirationDate = new Date(Date.now() + refreshTokenExpiry);
    const allowInsecureHttp =
      process.env.OPENID_ALLOW_INSECURE_HTTP === 'true' ||
      String(process.env.DOMAIN_SERVER || '').startsWith('http://');

    res.cookie('openid_id_token', tokenset.id_token, {
      expires: expirationDate,
      httpOnly: true,
      secure: false,
      sameSite: 'lax',
    });

    console.info('[TeamAI OpenID Patch] Persisted openid_id_token cookie for logout fallback');

    return result;
  };

  Object.defineProperty(authService, '__teamAiPatchedAuthService', {
    value: true,
    enumerable: false,
    configurable: false,
    writable: false,
  });

  return authService;
}

function patchLogoutController(controllerModule) {
  if (
    !controllerModule ||
    typeof controllerModule.logoutController !== 'function' ||
    controllerModule.__teamAiPatchedLogoutController === true
  ) {
    return controllerModule;
  }

  const originalLogoutController = controllerModule.logoutController;

  controllerModule.logoutController = async function patchedLogoutController(req, res, next) {
    const parsedCookies = req?.headers?.cookie ? cookie.parse(req.headers.cookie) : {};
    const authHeader = String(req?.headers?.authorization || '');
    const bearerToken = authHeader.startsWith('Bearer ') ? authHeader.slice(7) : '';
    const sessionTokens = req?.session?.openidTokens || {};
    const hasSessionIdToken = !!sessionTokens.idToken;
    const resolvedIdToken = sessionTokens.idToken || undefined;
    const resolvedRefreshToken =
      sessionTokens.refreshToken || parsedCookies.refreshToken || undefined;
    const shouldUseCasdoorLogout =
      req?.user?.provider === 'openid' &&
      normalizePatchBool(process.env.OPENID_USE_END_SESSION_ENDPOINT, false) &&
      hasSessionIdToken;

    if (req?.user?.provider === 'openid') {
      req.session = req.session || {};
      req.session.openidTokens = {
        ...sessionTokens,
        ...(resolvedIdToken ? { idToken: resolvedIdToken } : {}),
        ...(resolvedRefreshToken ? { refreshToken: resolvedRefreshToken } : {}),
      };

      if (!process.env.OPENID_MAX_LOGOUT_URL_LENGTH) {
        process.env.OPENID_MAX_LOGOUT_URL_LENGTH = '8192';
      }

      console.info('[TeamAI OpenID Patch] Logout diagnostics', {
        hasSession: !!req.session,
        hasSessionIdToken: !!sessionTokens.idToken,
        hasCookieIdToken: !!parsedCookies.openid_id_token,
        hasBearerToken: !!bearerToken,
        shouldUseCasdoorLogout,
        resolvedIdTokenLength: resolvedIdToken ? resolvedIdToken.length : 0,
        maxLogoutUrlLength: process.env.OPENID_MAX_LOGOUT_URL_LENGTH,
      });

      if (!shouldUseCasdoorLogout) {
        const originalSend = res.send;
        if (typeof originalSend === 'function' && !res.__teamAiPatchedLogoutSend) {
          res.send = function patchedLogoutSend(body) {
            if (body && typeof body === 'object' && body.redirect) {
              const fallbackRedirect =
                process.env.OPENID_POST_LOGOUT_REDIRECT_URI ||
                `${String(process.env.DOMAIN_CLIENT || '').replace(/\/+$/, '')}/login`;

              console.warn('[TeamAI OpenID Patch] Suppressing OpenID end-session redirect without session id_token', {
                fallbackRedirect,
                hasCookieIdToken: !!parsedCookies.openid_id_token,
              });

              return originalSend.call(this, {
                ...body,
                redirect: fallbackRedirect,
              });
            }

            return originalSend.call(this, body);
          };

          Object.defineProperty(res, '__teamAiPatchedLogoutSend', {
            value: true,
            enumerable: false,
            configurable: true,
          });
        }
      }
    }

    return originalLogoutController(req, res, next);
  };

  Object.defineProperty(controllerModule, '__teamAiPatchedLogoutController', {
    value: true,
    enumerable: false,
    configurable: false,
    writable: false,
  });

  return controllerModule;
}

function patchExpressResponse(response) {
  if (!response || typeof response.cookie !== 'function' || response.__teamAiPatchedResponse === true) {
    return response;
  }

  const originalCookie = response.cookie;
  const authCookieNames = new Set([
    'refreshToken',
    'token_provider',
    'openid_access_token',
    'openid_id_token',
    'openid_user_id',
  ]);

  response.cookie = function patchedCookie(name, value, options = {}) {
    const allowInsecureHttp =
      process.env.OPENID_ALLOW_INSECURE_HTTP === 'true' ||
      String(process.env.DOMAIN_SERVER || '').startsWith('http://');

    if (!allowInsecureHttp || !authCookieNames.has(name)) {
      return originalCookie.call(this, name, value, options);
    }

    const patchedOptions = {
      ...options,
      secure: false,
      sameSite: 'lax',
    };

    console.info('[TeamAI OpenID Patch] Rewriting auth cookie options', {
      name,
      secure: patchedOptions.secure,
      sameSite: patchedOptions.sameSite,
    });

    return originalCookie.call(this, name, value, patchedOptions);
  };

  Object.defineProperty(response, '__teamAiPatchedResponse', {
    value: true,
    enumerable: false,
    configurable: false,
    writable: false,
  });

  return response;
}

function patchExpressSession(sessionFactory) {
  if (
    typeof sessionFactory !== 'function' ||
    sessionFactory.__teamAiPatchedSessionFactory === true
  ) {
    return sessionFactory;
  }

  function wrappedSessionFactory(options = {}) {
    const isOpenIdSession =
      options?.secret &&
      process.env.OPENID_SESSION_SECRET &&
      options.secret === process.env.OPENID_SESSION_SECRET;

    if (!isOpenIdSession) {
      return sessionFactory(options);
    }

    console.info('[TeamAI OpenID Patch] Patching express-session options for OpenID flow');

    const patchedOptions = {
      ...options,
      saveUninitialized: true,
      cookie: {
        ...(options.cookie ?? {}),
        secure: false,
        sameSite: 'lax',
        path: '/',
      },
    };

    return sessionFactory(patchedOptions);
  }

  for (const key of Object.getOwnPropertyNames(sessionFactory)) {
    if (key === 'length' || key === 'name' || key === 'prototype') {
      continue;
    }
    const descriptor = Object.getOwnPropertyDescriptor(sessionFactory, key);
    if (descriptor) {
      Object.defineProperty(wrappedSessionFactory, key, descriptor);
    }
  }

  Object.setPrototypeOf(wrappedSessionFactory, Object.getPrototypeOf(sessionFactory));
  wrappedSessionFactory.prototype = sessionFactory.prototype;

  Object.defineProperty(wrappedSessionFactory, '__teamAiPatchedSessionFactory', {
    value: true,
    enumerable: false,
    configurable: false,
    writable: false,
  });

  return wrappedSessionFactory;
}

function patchOpenIdPassport(passportModule) {
  const Strategy = passportModule?.Strategy;
  if (!Strategy?.prototype || Strategy.__teamAiPatchedStrategy === true) {
    return passportModule;
  }

  const originalError = Strategy.prototype.error;
  const originalFail = Strategy.prototype.fail;
  const originalAuthenticate = Strategy.prototype.authenticate;

  Strategy.prototype.authenticate = function patchedAuthenticate(req, options) {
    const url = req?.originalUrl || req?.url;
    const beforeSessionKeys = req?.session ? Object.keys(req.session) : [];
    console.info('[TeamAI OpenID Patch] Strategy authenticate begin', {
      url,
      query: req?.query,
      beforeSessionKeys,
      sessionId: req?.sessionID,
    });

    const requestError = this.error;
    if (typeof requestError === 'function') {
      this.error = function patchedRequestError(err) {
        if (retryOpenIdAfterLostState(req, err)) {
          return;
        }
        return requestError.call(this, err);
      };
    }

    const requestFail = this.fail;
    if (typeof requestFail === 'function') {
      this.fail = function patchedRequestFail(challenge, status) {
        if (retryOpenIdAfterLostState(req, challenge)) {
          return;
        }
        return requestFail.call(this, challenge, status);
      };
    }

    // Patch res.redirect to force session save before redirecting
    // This ensures OIDC state (state, code_verifier) is persisted
    // before the browser follows the 302 to the IdP
    const originalRedirect = req?.res?.redirect;
    if (req?.res && typeof req.res.redirect === 'function' && !req.res.__teamAiPatchedRedirect) {
      req.res.redirect = function patchedRedirect(status, url) {
        // Handle (url) and (status, url) argument forms
        const redirectUrl = typeof status === 'string' ? status : url;
        if (
          req.session?.teamAiOpenIdStateRetry &&
          isOpenIdCallbackRequest(req) &&
          !isOAuthErrorRedirect(redirectUrl, req) &&
          !isOpenIdStartRedirect(redirectUrl, req)
        ) {
          delete req.session.teamAiOpenIdStateRetry;
        }
        if (req.session && typeof req.session.save === 'function') {
          console.info('[TeamAI OpenID Patch] Force-saving session before redirect', {
            sessionId: req.sessionID,
            sessionKeys: Object.keys(req.session),
            redirectUrl: typeof redirectUrl === 'string' ? redirectUrl.substring(0, 80) : '?',
          });
          req.session.save((err) => {
            if (err) {
              console.error('[TeamAI OpenID Patch] Session save before redirect failed:', err);
            }
            // Unpatch to avoid recursion
            req.res.redirect = originalRedirect;
            if (typeof status === 'string') {
              return originalRedirect.call(this, status);
            }
            return originalRedirect.call(this, status, url);
          });
          return;
        }
        if (typeof status === 'string') {
          return originalRedirect.call(this, status);
        }
        return originalRedirect.call(this, status, url);
      };
      Object.defineProperty(req.res, '__teamAiPatchedRedirect', {
        value: true,
        enumerable: false,
        configurable: true,
      });
    }

    const result = originalAuthenticate.call(this, req, options);
    Promise.resolve(result)
      .then(() => {
        const afterSessionKeys = req?.session ? Object.keys(req.session) : [];
        console.info('[TeamAI OpenID Patch] Strategy authenticate end', {
          url,
          afterSessionKeys,
          sessionId: req?.sessionID,
          sessionData: req?.session,
        });
      })
      .catch((err) => {
        console.error(
          '[TeamAI OpenID Patch] Strategy authenticate rejected',
          err && (err.stack || err.message || err),
        );
      });
    return result;
  };

  Strategy.prototype.error = function patchedError(err) {
    console.error('[TeamAI OpenID Patch] Strategy error', err && (err.stack || err.message || err));
    return originalError.call(this, err);
  };

  Strategy.prototype.fail = function patchedFail(challenge, status) {
    console.error('[TeamAI OpenID Patch] Strategy fail', { challenge, status });
    return originalFail.call(this, challenge, status);
  };

  Object.defineProperty(Strategy, '__teamAiPatchedStrategy', {
    value: true,
    enumerable: false,
    configurable: false,
    writable: false,
  });

  return passportModule;
}

function patchUserController(controllerModule) {
  if (
    !controllerModule ||
    controllerModule.__teamAiPatchedUserController === true ||
    typeof controllerModule.getUserController !== 'function'
  ) {
    return controllerModule;
  }

  const originalGetUserController = controllerModule.getUserController;

  controllerModule.getUserController = function patchedGetUserController(req, res, next) {
    const originalSend = res.send;
    if (typeof originalSend === 'function' && res.__teamAiPatchedUserSend !== true) {
      res.send = function patchedUserSend(body) {
        let patchedBody = body;
        try {
          if (body && typeof body === 'object' && !Buffer.isBuffer(body)) {
            patchedBody = applyDisplayUserInfo(body, req);
          }
        } catch (err) {
          console.error(
            '[TeamAI OpenID Patch] Failed to apply user display identifier',
            err && (err.stack || err.message || err),
          );
        }
        return originalSend.call(this, patchedBody);
      };

      Object.defineProperty(res, '__teamAiPatchedUserSend', {
        value: true,
        enumerable: false,
        configurable: true,
      });
    }

    return originalGetUserController.call(this, req, res, next);
  };

  Object.defineProperty(controllerModule, '__teamAiPatchedUserController', {
    value: true,
    enumerable: false,
    configurable: false,
    writable: false,
  });

  return controllerModule;
}

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

  if (
    request === '@librechat/api' ||
    request === '/app/packages/api' ||
    request === '/app/packages/api/dist/index.js'
  ) {
    return patchLibreChatApi(loaded);
  }

  if (request === 'express-session') {
    return patchExpressSession(loaded);
  }

  if (request === 'fs') {
    return patchFs(loaded);
  }

  if (request === 'express/lib/response') {
    return patchExpressResponse(loaded);
  }

  if (
    request === '~/server/services/AuthService' ||
    request === '/app/api/server/services/AuthService.js'
  ) {
    return patchAuthService(loaded);
  }

  if (request === '~/models' || request === '/app/api/models' || request === '/app/api/models/index.js') {
    return patchModels(loaded);
  }

  if (
    request === '~/server/controllers/auth/LogoutController' ||
    request === '/app/api/server/controllers/auth/LogoutController.js'
  ) {
    return patchLogoutController(loaded);
  }

  if (
    request === '~/server/controllers/UserController' ||
    request === '/app/api/server/controllers/UserController.js'
  ) {
    return patchUserController(loaded);
  }

  if (request === 'openid-client/passport' || request === '/app/api/node_modules/openid-client/passport') {
    return patchOpenIdPassport(loaded);
  }

  if (request === 'openid-client' || request === '/app/api/node_modules/openid-client') {
    return wrapOpenIdClient(loaded);
  }

  return loaded;
};
