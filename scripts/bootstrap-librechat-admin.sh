#!/usr/bin/env bash
set -euo pipefail

source "$(cd "$(dirname "$0")" && pwd)/_common.sh"

require_cmd docker
prepare_env_file
load_env

default_admin_enabled="$(normalize_bool "${LIBRECHAT_DEFAULT_ADMIN_ENABLED:-true}")"
default_admin_casdoor_enabled="$(normalize_bool "${LIBRECHAT_DEFAULT_ADMIN_CASDOOR_ENABLED:-true}")"
first_user_admin_enabled="$(normalize_bool "${LIBRECHAT_FIRST_USER_ADMIN_ENABLED:-true}")"

if [[ "$default_admin_enabled" != "true" && "$default_admin_casdoor_enabled" != "true" && "$first_user_admin_enabled" != "true" ]]; then
  info "LibreChat 默认管理员与首个用户自动提权均未启用，跳过"
  exit 0
fi

mongo_container="${LIBRECHAT_MONGODB_CONTAINER:-$(container_name librechat-mongodb)}"
librechat_container="${LIBRECHAT_CONTAINER:-$(container_name librechat)}"

wait_for_container() {
  local container="$1"
  local label="$2"
  local attempt

  for attempt in $(seq 1 60); do
    if [[ "$(docker inspect -f '{{.State.Running}}' "$container" 2>/dev/null || true)" == "true" ]]; then
      return 0
    fi
    sleep 2
  done

  die "${label} 容器未运行: ${container}"
}

wait_for_mongo() {
  local attempt

  for attempt in $(seq 1 60); do
    if docker exec "$mongo_container" mongosh LibreChat --quiet --eval 'db.runCommand({ ping: 1 }).ok' 2>/dev/null | grep -qx '1'; then
      return 0
    fi
    sleep 2
  done

  die "LibreChat MongoDB 未就绪: ${mongo_container}"
}

wait_for_casdoor_tables() {
  local attempt ready

  for attempt in $(seq 1 60); do
    ready="$(docker_compose exec -T new-api-postgres \
      psql -U "$NEW_API_DB_USER" -d "$CASDOOR_DB_NAME" -qtAc \
      "select count(*) from information_schema.tables where table_schema = 'public' and table_name in ('organization', 'application', 'user');" \
      2>/dev/null | tr -d '[:space:]' || true)"
    if [[ "$ready" == "3" ]]; then
      return 0
    fi
    sleep 2
  done

  return 1
}

hash_admin_password() {
  local password="$1"

  docker exec -i \
    -w /app \
    -e TEAMAI_ADMIN_PASSWORD="$password" \
    "$librechat_container" \
    node - <<'NODE'
const bcrypt = require('bcryptjs');
const password = process.env.TEAMAI_ADMIN_PASSWORD || '';

if (password.length < 8 || password.length > 128) {
  console.error('LIBRECHAT_DEFAULT_ADMIN_PASSWORD 长度必须在 8 到 128 个字符之间');
  process.exit(1);
}

process.stdout.write(bcrypt.hashSync(password, 10));
NODE
}

wait_for_container "$mongo_container" "LibreChat MongoDB"
wait_for_mongo

admin_password_hash=""
if [[ "$default_admin_enabled" == "true" ]]; then
  wait_for_container "$librechat_container" "LibreChat"
  admin_password_hash="$(hash_admin_password "${LIBRECHAT_DEFAULT_ADMIN_PASSWORD:-}")"
fi

docker exec \
  -e TEAMAI_DEFAULT_ADMIN_ENABLED="$default_admin_enabled" \
  -e TEAMAI_FIRST_USER_ADMIN_ENABLED="$first_user_admin_enabled" \
  -e TEAMAI_DEFAULT_ADMIN_EMAIL="${LIBRECHAT_DEFAULT_ADMIN_EMAIL:-}" \
  -e TEAMAI_DEFAULT_ADMIN_USERNAME="${LIBRECHAT_DEFAULT_ADMIN_USERNAME:-}" \
  -e TEAMAI_DEFAULT_ADMIN_NAME="${LIBRECHAT_DEFAULT_ADMIN_NAME:-}" \
  -e TEAMAI_DEFAULT_ADMIN_PASSWORD_HASH="$admin_password_hash" \
  "$mongo_container" \
  mongosh LibreChat --quiet --eval '
const defaultAdminEnabled = process.env.TEAMAI_DEFAULT_ADMIN_ENABLED === "true";
const firstUserAdminEnabled = process.env.TEAMAI_FIRST_USER_ADMIN_ENABLED === "true";
const defaultAdminEmail = String(process.env.TEAMAI_DEFAULT_ADMIN_EMAIL || "").trim().toLowerCase();
const defaultAdminUsername = String(process.env.TEAMAI_DEFAULT_ADMIN_USERNAME || "team-ai-admin").trim().toLowerCase();
const defaultAdminName = String(process.env.TEAMAI_DEFAULT_ADMIN_NAME || "Team AI Admin").trim();
const defaultAdminPasswordHash = String(process.env.TEAMAI_DEFAULT_ADMIN_PASSWORD_HASH || "");
const now = new Date();

function assertValidEmail(email) {
  if (!/^\S+@\S+\.\S+$/.test(email)) {
    throw new Error("LIBRECHAT_DEFAULT_ADMIN_EMAIL 不是有效邮箱");
  }
}

if (defaultAdminEnabled) {
  assertValidEmail(defaultAdminEmail);
  if (!defaultAdminPasswordHash.startsWith("$2")) {
    throw new Error("默认管理员密码哈希生成失败");
  }

  const result = db.users.updateOne(
    { email: defaultAdminEmail },
    {
      $set: {
        name: defaultAdminName,
        username: defaultAdminUsername,
        emailVerified: true,
        password: defaultAdminPasswordHash,
        provider: "local",
        role: "ADMIN",
        avatar: null,
        termsAccepted: true,
        updatedAt: now,
      },
      $setOnInsert: {
        email: defaultAdminEmail,
        refreshToken: [],
        favorites: [],
        personalization: { memories: true },
        createdAt: now,
      },
    },
    { upsert: true },
  );

  if (result.upsertedCount > 0) {
    print(`[TeamAI LibreChat Admin] 已创建默认 ADMIN 用户: ${defaultAdminEmail}`);
  } else {
    print(`[TeamAI LibreChat Admin] 已校正默认 ADMIN 用户: ${defaultAdminEmail}`);
  }
}

db.systemgrants.updateOne(
  { principalType: "role", principalId: "ADMIN", capability: "access:admin" },
  {
    $set: { updatedAt: now },
    $setOnInsert: { createdAt: now, grantedAt: now },
  },
  { upsert: true },
);

const userMarketplaceRoleUpdate = db.roles.updateOne(
  { name: "USER" },
  {
    $set: {
      "permissions.MARKETPLACE.USE": true,
      "permissions.AGENTS.USE": true,
      updatedAt: now,
    },
  },
);

if (userMarketplaceRoleUpdate.matchedCount > 0) {
  print("[TeamAI LibreChat Admin] 已开放 USER 角色的智能体市场可见权限");
} else {
  print("[TeamAI LibreChat Admin] 未找到 USER 角色，跳过智能体市场可见权限校正");
}

if (firstUserAdminEnabled) {
  const firstUserFilter = { provider: { $ne: "anonymous" } };
  if (defaultAdminEmail) {
    firstUserFilter.email = { $ne: defaultAdminEmail };
  }

  const firstUser = db.users.find(firstUserFilter).sort({ createdAt: 1, _id: 1 }).limit(1).toArray()[0];
  if (firstUser && firstUser.role !== "ADMIN") {
    db.users.updateOne({ _id: firstUser._id }, { $set: { role: "ADMIN", updatedAt: now } });
    print(`[TeamAI LibreChat Admin] 已将首个注册用户提升为 ADMIN: ${firstUser.email}`);
  } else if (firstUser) {
    print(`[TeamAI LibreChat Admin] 首个注册用户已是 ADMIN: ${firstUser.email}`);
  } else {
    print("[TeamAI LibreChat Admin] 尚无非默认注册用户，后续首个注册用户会自动成为 ADMIN");
  }
}

print(`[TeamAI LibreChat Admin] 当前 ADMIN 用户数: ${db.users.countDocuments({ role: "ADMIN" })}`);
'

if [[ "$default_admin_enabled" == "true" && "$default_admin_casdoor_enabled" == "true" ]]; then
  if wait_for_casdoor_tables; then
    casdoor_password_salt="$(random_hex 20)"
    casdoor_created_time="$(date -u +'%Y-%m-%dT%H:%M:%SZ')"
    docker_compose exec -T new-api-postgres \
      psql -v ON_ERROR_STOP=1 \
        -v owner="${CASDOOR_USER_ORGANIZATION_NAME:-team-ai}" \
        -v name="${LIBRECHAT_DEFAULT_ADMIN_USERNAME:-team-ai-admin}" \
        -v created_time="$casdoor_created_time" \
        -v display_name="${LIBRECHAT_DEFAULT_ADMIN_NAME:-Team AI Admin}" \
        -v password="$admin_password_hash" \
        -v password_salt="$casdoor_password_salt" \
        -v email="${LIBRECHAT_DEFAULT_ADMIN_EMAIL:-__PLACEHOLDER_EMAIL__}" \
        -v country_code="${CASDOOR_ADMIN_COUNTRY_CODE:-CN}" \
        -v signup_application="${CASDOOR_APPLICATION_NAME:-team-ai-librechat}" \
        -U "$NEW_API_DB_USER" -d "$CASDOOR_DB_NAME" <<'SQL'
INSERT INTO "user" (
  owner,
  name,
  created_time,
  updated_time,
  id,
  type,
  password,
  password_salt,
  password_type,
  display_name,
  email,
  email_verified,
  phone,
  country_code,
  language,
  score,
  karma,
  ranking,
  balance,
  balance_credit,
  currency,
  balance_currency,
  is_default_avatar,
  is_online,
  is_admin,
  is_forbidden,
  is_deleted,
  signup_application,
  register_type,
  register_source
) VALUES (
  :'owner',
  :'name',
  :'created_time',
  :'created_time',
  :'name',
  'normal-user',
  :'password',
  :'password_salt',
  'bcrypt',
  :'display_name',
  :'email',
  true,
  '',
  :'country_code',
  '',
  2000,
  0,
  1,
  0,
  0,
  '',
  '',
  false,
  false,
  false,
  false,
  false,
  :'signup_application',
  'Add User',
  :'signup_application'
)
ON CONFLICT (owner, name) DO UPDATE SET
  updated_time = EXCLUDED.updated_time,
  display_name = EXCLUDED.display_name,
  password = EXCLUDED.password,
  password_salt = EXCLUDED.password_salt,
  password_type = EXCLUDED.password_type,
  email = EXCLUDED.email,
  email_verified = EXCLUDED.email_verified,
  country_code = EXCLUDED.country_code,
  is_admin = false,
  is_forbidden = false,
  is_deleted = false,
  signup_application = EXCLUDED.signup_application,
  register_type = EXCLUDED.register_type,
  register_source = EXCLUDED.register_source;
SQL
    info "Casdoor 默认业务管理员已同步: ${CASDOOR_USER_ORGANIZATION_NAME:-team-ai}/${LIBRECHAT_DEFAULT_ADMIN_USERNAME:-team-ai-admin}"
  else
    warn "Casdoor user 表未就绪，已跳过默认业务管理员同步"
  fi
fi

info "LibreChat 管理员初始化完成"
