# OpenSearch on Railway

Source for the Railway template **OpenSearch** (OpenSearch 3.9.0 + OpenSearch Dashboards 3.9.0, security plugin on).

The template uses the official images, pinned by digest:

- `opensearchproject/opensearch:3.9.0@sha256:3b55f6b6249cfdb92b52ee59adc8a266203ba9ef9f5d82544fad6f1af2f3609e`
- `opensearchproject/opensearch-dashboards:3.9.0@sha256:256d4cea5928868ac09bca642a0ac8285a2b7e4b7fdd45c4ec06e75a5cf3184c`

No image is built. Railway runs a start command on each service:

- `start-command-opensearch.txt`: writes `start-opensearch.sh` (base64 inline) to `/tmp` and runs it.
- `start-command-dashboards.txt`: starts Dashboards against OpenSearch over the private network.

## What `start-opensearch.sh` does

1. Runs as root (`RAILWAY_RUN_UID=0`) only to remove `lost+found` and chown the root-owned Railway volume to uid 1000, then drops to uid 1000 with `chroot --userspec` (the image has no `su`, `gosu` or `setpriv`).
2. Runs the security plugin's demo installer to create the config files, then:
   - turns off TLS on the HTTP layer (Railway's edge serves HTTPS; the private network is HTTP),
   - replaces `internal_users.yml` with only two users: `admin` (password `OPENSEARCH_INITIAL_ADMIN_PASSWORD`) and `kibanaserver` (password `KIBANASERVER_PASSWORD`). The demo users with public default passwords (`kibanaserver`, `kibanaro`, `logstash`, `readall`, `snapshotrestore`, `anomalyadmin`) are not created.
3. Starts a single node with `discovery.type=single-node`, HTTP on `[::]:9200` (public domain and private network), the transport layer bound to `127.0.0.1` only, and `cluster.default_number_of_replicas=0` so new indices stay green.

The users are written to the security index on first boot. After that the index is the source of truth: change passwords in Dashboards (Security → Internal users), not by editing the variables.
