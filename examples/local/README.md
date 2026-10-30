# Local example

Applies circuit-langfuse to a throwaway Rocky Linux 10 container with systemd, with [circuit-postgres](https://github.com/conn3xorg/circuit-postgres) and [circuit-valkey](https://github.com/conn3xorg/circuit-valkey) on the same host. You need Conn3x, Podman, and about 4 GB of memory free for the container: ClickHouse, the two Langfuse processes, PostgreSQL and Valkey all run inside it.

Langfuse runs under Podman inside that container, so the host container is privileged, which is simplest with rootful Podman. On a Mac, use the Podman machine's root connection, and give the machine at least 6 GB. On Linux, use `sudo podman`:

```sh
export CONTAINER_CONNECTION=podman-machine-default-root   # macOS
export PODMAN="sudo podman"                               # Linux
./up.sh
conn3x init
conn3x apply
conn3x plan
```

The first apply takes a few minutes: it installs PostgreSQL, Valkey and Podman, pulls about 3.6 GB of images and waits while Langfuse sets up its databases. The second plan says `No changes.` The example's passwords and keys are defaults in `main.tf`, which you'd never keep on a real host.

Langfuse listens on `127.0.0.1:3000` inside the container. To ask it something, use the `wget` in its own image:

```sh
ssh -p 2222 -i id_ed25519 -o UserKnownHostsFile=known_hosts root@127.0.0.1 \
  podman exec langfuse-web wget -qO- http://127.0.0.1:3000/api/public/health
```

The answer includes `"status":"OK"`. The example's project has the keys `pk-lf-example` and `sk-lf-example-not-secret`, and the owner signs in as `admin@example.com` with `tracing-paper-kite`.

`up.sh` listens on `127.0.0.1:2222`. Set `PORT` to use another port, and pass the same port to Conn3x with `-var port=PORT`. Set `CONTAINERFILE` to test another distro, such as one of the images in Conn3x's `test/images`, which CI uses.

`./down.sh` removes the container, its volumes, the key and the state.
