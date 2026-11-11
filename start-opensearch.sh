set -e
H=/usr/share/opensearch
if [ "$(id -u)" = 0 ]; then
  rm -rf $H/data/lost+found
  [ "$(stat -c %u $H/data)" = 1000 ] || chown -R 1000:1000 $H/data
  exec chroot --userspec=1000:1000 / env HOME=$H bash -c "cd $H && bash /tmp/start-os.sh"
fi
cd $H
[ -w $H/data ] || { echo "ERROR: $H/data is not writable; set RAILWAY_RUN_UID=0"; exit 1; }
[ -n "$OPENSEARCH_INITIAL_ADMIN_PASSWORD" ] && [ -n "$KIBANASERVER_PASSWORD" ] || { echo "ERROR: OPENSEARCH_INITIAL_ADMIN_PASSWORD and KIBANASERVER_PASSWORD must be set"; exit 1; }
S=$H/plugins/opensearch-security/tools
if ! grep -q '^plugins.security' config/opensearch.yml; then
  bash $S/install_demo_configuration.sh -y -i -s >/tmp/demo.log 2>&1 || { cat /tmp/demo.log; exit 1; }
  sed -i 's/^plugins.security.ssl.http.enabled:.*/plugins.security.ssl.http.enabled: false/' config/opensearch.yml
  hp() { h=$(OPENSEARCH_JAVA_OPTS= $S/hash.sh -p "$1" 2>/dev/null | tail -n1); case "$h" in \$2*) echo "$h";; *) echo "ERROR: password hashing failed" >&2; kill $$;; esac; }
  cat > config/opensearch-security/internal_users.yml <<YML
_meta:
  type: "internalusers"
  config_version: 2
admin:
  hash: "$(hp "$OPENSEARCH_INITIAL_ADMIN_PASSWORD")"
  reserved: true
  backend_roles: ["admin"]
  description: "Admin user"
kibanaserver:
  hash: "$(hp "$KIBANASERVER_PASSWORD")"
  reserved: true
  description: "OpenSearch Dashboards server user"
YML
fi
export DISABLE_INSTALL_DEMO_CONFIG=true DISABLE_PERFORMANCE_ANALYZER_AGENT_CLI=true
export OPENSEARCH_JAVA_OPTS="${OPENSEARCH_JAVA_OPTS:--Xms1g -Xmx1g}"
exec ./opensearch-docker-entrypoint.sh opensearch -Ecluster.name=opensearch -Enode.name=opensearch-node1 -Ediscovery.type=single-node -Ehttp.host=:: -Ehttp.port=9200 -Etransport.host=127.0.0.1 -Ecluster.default_number_of_replicas=0
