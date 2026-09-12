// SPDX-License-Identifier: GPL-3.0-or-later
import { createMatchServer } from "./server.js";
const port = Number(process.env.PORT ?? 8080);
const app = createMatchServer({ port });
const { server, httpServer } = app;
server.on("listening", () =>
  console.log(
    `Battle Chess Arena server listening on :${server.address().port}`,
  ),
);
server.on("error", (error) => {
  console.error(`Server failed: ${error.code ?? "UNKNOWN"}`);
  process.exitCode = 1;
});
httpServer.on("error", (error) => {
  console.error(`HTTP server failed: ${error.code ?? "UNKNOWN"}`);
  process.exitCode = 1;
});

let stopping = false;
async function stop(signal) {
  if (stopping) return;
  stopping = true;
  console.log(`Received ${signal}; closing connections`);
  try {
    await app.close();
  } catch (error) {
    console.error(`Shutdown failed: ${error.code ?? "UNKNOWN"}`);
    process.exitCode = 1;
  }
}
process.on("SIGTERM", () => void stop("SIGTERM"));
process.on("SIGINT", () => void stop("SIGINT"));
