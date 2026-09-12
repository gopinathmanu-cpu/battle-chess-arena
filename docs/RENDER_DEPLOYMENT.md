# Free multiplayer server on Render

The project includes a Render Blueprint in `render.yaml`. It deploys one free
Node web service in Singapore with managed TLS and a health check.

## Deploy

1. Push this project to a GitHub, GitLab, or Bitbucket repository.
2. In the Render dashboard, choose **New > Blueprint**.
3. Connect the repository and select `render.yaml`.
4. Review the single free service and apply the Blueprint.
5. Open `https://battle-chess-arena-server.onrender.com/health`. A healthy
   deployment returns `{"status":"ok","protocolVersion":2}`.

The game endpoint is the same host with the WebSocket scheme:
`wss://battle-chess-arena-server.onrender.com`. If Render adds a suffix to the
service name, copy the exact hostname from its dashboard.

## Build the app with the hosted endpoint

Replace the example URL below with the exact Render hostname:

```bash
flutter build apk --release \
  --dart-define=ONLINE_SERVER_URL=wss://battle-chess-arena-server.onrender.com
```

The lobby still keeps the endpoint editable, which makes local-server testing
possible. An app built without `ONLINE_SERVER_URL` defaults to
`ws://10.0.2.2:8080` on Android and `ws://127.0.0.1:8080` elsewhere.

## Free-tier behavior

The service stores rooms in memory. Render sleeps a free service after 15
minutes with no inbound HTTP or WebSocket traffic and may restart it during
maintenance. A sleeping server can take about a minute to wake, and a restart
removes open rooms. Connected clients send heartbeats, so an active lobby or
game produces inbound WebSocket traffic.

This free deployment is intended for multiplayer testing. Before a public
production launch, add durable shared room state, authentication, rate limits,
monitoring, and automated cleanup.
