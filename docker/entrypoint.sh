#!/usr/bin/env bash
set -euo pipefail

AIL_HOME=${AIL_HOME:-/opt/ail}
export AIL_HOME
export AIL_BIN="$AIL_HOME/bin"
export AIL_FLASK="$AIL_HOME/var/www"
export PYTHONUNBUFFERED=1

mkdir -p "$AIL_HOME/logs" "$AIL_HOME/PASTES" "$AIL_HOME/FILES" "$AIL_HOME/crawled"

if [ ! -f "$AIL_HOME/configs/core.cfg" ]; then
  cp "$AIL_HOME/configs/docker/core.cfg" "$AIL_HOME/configs/core.cfg"
fi

if [ ! -f "$AIL_FLASK/server.crt" ] || [ ! -f "$AIL_FLASK/server.key" ]; then
  echo "[ail] generating TLS certificates"
  pushd "$AIL_HOME/tools/gen_cert" >/dev/null
  ./gen_root.sh
  ./gen_cert.sh
  popd >/dev/null
  cp "$AIL_HOME/tools/gen_cert/server.crt" "$AIL_FLASK/server.crt"
  cp "$AIL_HOME/tools/gen_cert/server.key" "$AIL_FLASK/server.key"
fi

if [ ! -f "$AIL_HOME/files/misp-taxonomies/MANIFEST.json" ]; then
  echo "[ail] fetching misp-taxonomies"
  git clone https://github.com/MISP/misp-taxonomies.git "$AIL_HOME/files/misp-taxonomies"
fi

wait_for_service() {
  local name="$1"
  local host="$2"
  local port="$3"

  echo "[ail] waiting for ${name} at ${host}:${port}"
  python - <<PY
import socket
import time
host = "${host}"
port = int("${port}")
deadline = time.time() + 120
while time.time() < deadline:
    try:
        with socket.create_connection((host, port), timeout=2):
            raise SystemExit(0)
    except OSError:
        time.sleep(2)
raise SystemExit(1)
PY
}

wait_for_service "redis-cache" "redis-cache" 6379
wait_for_service "redis-log" "redis-log" 6380
wait_for_service "redis-queue" "redis-queue" 6381
wait_for_service "kvrocks" "kvrocks" 6383

python "$AIL_BIN/AIL_Init.py"

pids=()

start_bg() {
  echo "[ail] starting $1"
  shift
  "$@" &
  pids+=("$!")
}

if command -v log_subscriber >/dev/null 2>&1; then
  start_bg "log_subscriber" log_subscriber -p 6380 -c Script -l "$AIL_HOME/logs/"
fi

start_bg "ail_2_ail_server" python "$AIL_BIN/core/ail_2_ail_server.py"
start_bg "Sync_importer" python "$AIL_BIN/core/Sync_importer.py"
start_bg "Sync_manager" python "$AIL_BIN/core/Sync_manager.py"
start_bg "ZMQImporter" python "$AIL_BIN/importer/ZMQImporter.py"
start_bg "FeederImporter" python "$AIL_BIN/importer/FeederImporter.py"
start_bg "CrawlerImporter" python "$AIL_BIN/importer/CrawlerImporter.py"
start_bg "D4_client" python "$AIL_BIN/core/D4_client.py"
translation_url=$(python - <<'PY'
import configparser
config = configparser.ConfigParser()
config.read("/opt/ail/configs/core.cfg")
print(config.get("Translation", "libretranslate", fallback="").strip())
PY
)
if [ -n "$translation_url" ]; then
  start_bg "Translation" python "$AIL_BIN/modules/Translation.py"
else
  echo "[ail] skipping Translation module (libretranslate is not configured)"
fi
start_bg "UpdateBackground" python "$AIL_BIN/update-background.py"

start_bg "Mixer" python "$AIL_BIN/modules/Mixer.py"
start_bg "Global" python "$AIL_BIN/modules/Global.py"
start_bg "Categ" python "$AIL_BIN/modules/Categ.py"
start_bg "Tags" python "$AIL_BIN/modules/Tags.py"
start_bg "SubmitPaste" python "$AIL_BIN/modules/SubmitPaste.py"
start_bg "Crawler" python "$AIL_BIN/crawlers/Crawler.py"
start_bg "Sync_module" python "$AIL_BIN/core/Sync_module.py"

start_bg "ApiKey" python "$AIL_BIN/modules/ApiKey.py"
start_bg "Credential" python "$AIL_BIN/modules/Credential.py"
start_bg "CreditCards" python "$AIL_BIN/modules/CreditCards.py"
start_bg "Cryptocurrency" python "$AIL_BIN/modules/Cryptocurrencies.py"
start_bg "CveModule" python "$AIL_BIN/modules/CveModule.py"
start_bg "Decoder" python "$AIL_BIN/modules/Decoder.py"
start_bg "Duplicates" python "$AIL_BIN/modules/Duplicates.py"
start_bg "Iban" python "$AIL_BIN/modules/Iban.py"
start_bg "IPAddress" python "$AIL_BIN/modules/IPAddress.py"
start_bg "Keys" python "$AIL_BIN/modules/Keys.py"
start_bg "Languages" python "$AIL_BIN/modules/Languages.py"
start_bg "Mail" python "$AIL_BIN/modules/Mail.py"
start_bg "Onion" python "$AIL_BIN/modules/Onion.py"
start_bg "PgpDump" python "$AIL_BIN/modules/PgpDump.py"
start_bg "Phone" python "$AIL_BIN/modules/Phone.py"
start_bg "Telegram" python "$AIL_BIN/modules/Telegram.py"
start_bg "Tools" python "$AIL_BIN/modules/Tools.py"
start_bg "TrackingId" python "$AIL_BIN/modules/TrackingId.py"
start_bg "Hosts" python "$AIL_BIN/modules/Hosts.py"
start_bg "DomClassifier" python "$AIL_BIN/modules/DomClassifier.py"
start_bg "Urls" python "$AIL_BIN/modules/Urls.py"
start_bg "SQLInjectionDetection" python "$AIL_BIN/modules/SQLInjectionDetection.py"
start_bg "Indexer" python "$AIL_BIN/modules/Indexer.py"
start_bg "MISP_Thehive_Auto_Push" python "$AIL_BIN/modules/MISP_Thehive_Auto_Push.py"
start_bg "Exif" python "$AIL_BIN/modules/Exif.py"
start_bg "OcrExtractor" python "$AIL_BIN/modules/OcrExtractor.py"
start_bg "CodeReader" python "$AIL_BIN/modules/CodeReader.py"
start_bg "CEDetector" python "$AIL_BIN/modules/CEDetector.py"

start_bg "Tracker_Term" python "$AIL_BIN/trackers/Tracker_Term.py"
start_bg "Tracker_Typo_Squatting" python "$AIL_BIN/trackers/Tracker_Typo_Squatting.py"
start_bg "Tracker_Regex" python "$AIL_BIN/trackers/Tracker_Regex.py"
start_bg "Tracker_Yara" python "$AIL_BIN/trackers/Tracker_Yara.py"
start_bg "Retro_Hunt" python "$AIL_BIN/trackers/Retro_Hunt.py"

cleanup() {
  echo "[ail] shutting down"
  if [ ${#pids[@]} -gt 0 ]; then
    kill "${pids[@]}" 2>/dev/null || true
  fi
}
trap cleanup EXIT

exec python "$AIL_FLASK/Flask_server.py"
