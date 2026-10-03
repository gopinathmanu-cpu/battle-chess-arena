// SPDX-License-Identifier: GPL-3.0-or-later
import { createMatchServer } from "./server.js";
import { FirestoreStateStore } from './firestore-state-store.js';
const port = Number(process.env.PORT ?? 8080);
const stateStore = process.env.FIRESTORE_PROJECT_ID
  ? new FirestoreStateStore({ projectId: process.env.FIRESTORE_PROJECT_ID,
      database: process.env.FIRESTORE_DATABASE ?? '(default)' }) : null;
// A load failure aborts startup; never replace durable games with an empty map.
const initialState = stateStore ? await stateStore.load() : null;
const app = createMatchServer({ port, stateStore, initialState });
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
