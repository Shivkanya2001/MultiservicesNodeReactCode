# MultiservicesNodeReactCode
k8s Full-Stack (React + Node/Express + MySQL) on Minikube — Windows (Docker driver)

This README operationalizes everything we iterated on: container builds, runtime config, Kubernetes manifests, and a clean, production-like path that eliminates CORS by proxying API calls through Nginx.

TL;DR: Open UI with minikube service web --url. The React app calls same-origin /api/* and Nginx proxies to api-service:4000 inside the cluster. No more __API_URL__, no browser DNS issues, no CORS drama.

0) Prerequisites

Windows 10/11 with Docker Desktop (WSL2 backend).

Minikube using the Docker driver.

kubectl and docker in PATH.

A Docker Hub account (for shivkanyadoiphode/* images).

1) Repository Layout (expected)
k8s-fullstack-mysql-app/
├─ backend/                 # Node/Express API
│  ├─ server.js
│  └─ package.json
├─ frontend/                # React SPA
│  ├─ public/index.html
│  ├─ src/api.js
│  ├─ nginx.conf
│  ├─ Dockerfile
│  └─ package.json
├─ *.yaml                   # K8s manifests (db, api, adminer, secrets, pv/pvc, web, configmap, services)
└─ README.md

2) Backend (Node/Express)

server.js (core points only):

const express = require("express");
const cors = require("cors");
require("dotenv").config();

const { initDb, sequelize } = require("./db");
const usersRouter = require("./routes/users");

const app = express();
app.use(
  cors({
    origin: (process.env.CORS_ORIGIN || "http://localhost:3000").split(","),
  })
);
app.use(express.json());

app.get("/api/health", (_req, res) => res.json({ ok: true }));
app.use("/api/users", usersRouter);

const port = process.env.PORT || 4000;
(async () => {
  await initDb();
  await sequelize.sync({ alter: true }); // dev only
  app.listen(port, "0.0.0.0", () =>
    console.log(`API listening on http://0.0.0.0:${port}`)
  );
})();


K8s Service (pinned NodePort): api-service.yaml

apiVersion: v1
kind: Service
metadata:
  name: api-service
spec:
  type: NodePort
  selector:
    app: api
  ports:
    - port: 4000       # Cluster port
      targetPort: 4000 # Container port
      nodePort: 30001  # Stable NodePort for host access (if required)


Why pin the NodePort? Consistent external port for optional direct testing (http://127.0.0.1:30001/api) and health checks.

3) Frontend (React SPA)
3.1 public/index.html — load runtime config before the bundle
<!doctype html>
<html lang="en">
  <head>
    <meta charset="utf-8" />
    <link rel="manifest" href="%PUBLIC_URL%/manifest.json" />
    <title>User Management</title>
  </head>
  <body>
    <noscript>You need to enable JavaScript to run this app.</noscript>
    <div id="root"></div>

    <!-- Load runtime config BEFORE React bundles -->
    <script src="/config.js"></script>
  </body>
</html>

3.2 src/api.js — lazy base URL (resolves at call time)
// src/api.js
const getBase = () =>
  (typeof window !== "undefined" && window.REACT_APP_API_URL) ||
  process.env.REACT_APP_API_URL ||
  "/api"; // same-origin default

const asJsonOrThrow = async (res) => {
  if (!res.ok) {
    const msg = await res.text().catch(() => res.statusText);
    throw new Error(msg || `HTTP ${res.status}`);
  }
  if (res.status === 204) return null;
  return res.json();
};

export const api = {
  listUsers({ q = "", page = 1, pageSize = 20 } = {}) {
    const url = new URL(`${getBase()}/users`, window.location.origin);
    if (q) url.searchParams.set("q", q);
    url.searchParams.set("page", page);
    url.searchParams.set("pageSize", pageSize);
    return fetch(url.toString()).then(asJsonOrThrow);
  },
  createUser(payload) {
    return fetch(`${getBase()}/users`, {
      method: "POST",
      headers: { "Content-Type": "application/json" },
      body: JSON.stringify(payload),
    }).then(asJsonOrThrow);
  },
  updateUser(id, payload) {
    return fetch(`${getBase()}/users/${id}`, {
      method: "PUT",
      headers: { "Content-Type": "application/json" },
      body: JSON.stringify(payload),
    }).then(asJsonOrThrow);
  },
  deleteUser(id) {
    return fetch(`${getBase()}/users/${id}`, { method: "DELETE" }).then(
      async (res) => {
        if (res.ok || res.status === 204) return true;
        const msg = await res.text().catch(() => res.statusText);
        throw new Error(msg || `HTTP ${res.status}`);
      }
    );
  },
};

3.3 Nginx — Recommended (proxy) pattern → zero CORS

frontend/nginx.conf

server {
  listen 80;
  server_name _;

  root /usr/share/nginx/html;
  index index.html;

  # Runtime config consumed by React
  location /config.js {
    add_header Content-Type application/javascript;
    return 200 "window.REACT_APP_API_URL = '/api';";
  }

  # Reverse proxy to in-cluster API service
  location /api/ {
    proxy_pass         http://api-service:4000/api/;
    proxy_http_version 1.1;

    proxy_set_header   Host              $host;
    proxy_set_header   X-Real-IP         $remote_addr;
    proxy_set_header   X-Forwarded-For   $proxy_add_x_forwarded_for;
    proxy_set_header   X-Forwarded-Proto $scheme;

    proxy_connect_timeout 60s;
    proxy_send_timeout    60s;
    proxy_read_timeout    60s;
  }

  # SPA fallback
  location / {
    try_files $uri /index.html;
  }
}


With this, the browser calls http://127.0.0.1:<web-port>/api/... (same origin). Nginx handles the hop to api-service. No CORS, no DNS issues.

3.4 Frontend Dockerfile
# --- build ---
FROM node:20-alpine AS build
WORKDIR /app
COPY package*.json ./
RUN npm ci --no-audit --no-fund
COPY . .
# Build is independent of API URL; runtime config handles it
RUN npm run build

# --- serve ---
FROM nginx:alpine
RUN rm /etc/nginx/conf.d/default.conf
COPY nginx.conf /etc/nginx/conf.d/default.conf
COPY --from=build /app/build /usr/share/nginx/html
EXPOSE 80
CMD ["nginx", "-g", "daemon off;"]


No docker-entrypoint.sh needed in the proxy model. (If you prefer template replacement via API_URL, you can keep your entrypoint — but it’s not required here.)

4) Kubernetes: Config & Deploy
4.1 ConfigMap (app runtime & API CORS)

app-config.yaml

apiVersion: v1
kind: ConfigMap
metadata:
  name: app-config
data:
  PORT: "4000"
  # Grant API access to local dev + in-cluster web
  CORS_ORIGIN: "http://localhost:3000,http://web:80"


In the proxy pattern, the browser never calls the API directly across origins, so CORS is rarely exercised — still harmless to keep.

4.2 Web Deployment & Service

web-deployment.yaml

apiVersion: apps/v1
kind: Deployment
metadata:
  name: web
spec:
  replicas: 1
  selector:
    matchLabels:
      app: web
  template:
    metadata:
      labels:
        app: web
    spec:
      containers:
        - name: web
          image: shivkanyadoiphode/microservicesdeployment-web:<TAG> # e.g. v1.1.0
          ports:
            - containerPort: 80
          envFrom:
            - configMapRef:
                name: app-config
---
apiVersion: v1
kind: Service
metadata:
  name: web
spec:
  type: NodePort
  selector:
    app: web
  ports:
    - port: 80
      targetPort: 80
      nodePort: 30666


NodePort is convenient, but you’ll typically access via minikube service web --url on Windows Docker driver.

4.3 API Deployment

(You already have api-deployment.yaml — ensure PORT, CORS_ORIGIN, DB_* are wired via ConfigMap/Secret and containerPort is 4000.)

5) Build & Push Images

From repo root:

# Backend
docker build -t shivkanyadoiphode/microservicesdeployment-api:v1.0.0 -f backend/Dockerfile ./backend
docker push shivkanyadoiphode/microservicesdeployment-api:v1.0.0

# Frontend
docker build -t shivkanyadoiphode/microservicesdeployment-web:v1.1.0 -f frontend/Dockerfile ./frontend
docker push shivkanyadoiphode/microservicesdeployment-web:v1.1.0


Update web-deployment.yaml to use v1.1.0.

6) Deploy / Reset
Apply all manifests (from the YAML directory):
kubectl apply -f . --recursive
kubectl get pods -w

Clean reset if needed:
kubectl delete -f . --recursive

7) Access the App

Windows + Docker driver: Don’t browse to 192.168.49.2:<nodePort> — it often times out. Use Minikube’s local tunnel.

Open the UI:

minikube service web --url
# Keep this terminal open; copy the http://127.0.0.1:xxxxx URL into your browser


Sanity checks:

# From your laptop:
curl http://127.0.0.1:<WEB_PORT>/config.js
# -> window.REACT_APP_API_URL = '/api';

curl http://127.0.0.1:<WEB_PORT>/api/health
# -> {"ok":true}


(Inside the cluster)

kubectl exec -it deploy/web -- curl -s http://api-service:4000/api/health
# -> {"ok":true}

8) Troubleshooting Matrix
Symptom	Root Cause	Resolution
ERR_NAME_NOT_RESOLVED calling http://api-service:4000/... from browser	Browser can’t resolve in-cluster DNS	Use proxy model (/api via Nginx). Or use minikube service api-service --url and set API_URL to http://127.0.0.1:<port>/api.
ERR_CONNECTION_TIMED_OUT to 192.168.49.2:<nodePort>	Windows can’t reach Minikube VM IP directly with Docker driver	Use minikube service <svc> --url (tunnels to 127.0.0.1).
405 Not Allowed / requests to __API_URL__	Placeholder leaked into bundle; config.js not honored	Ensure public/index.html loads /config.js before bundles; switch api.js to lazy getter.
Web pod CrashLoopBackOff; event: “configmap not found”	Refers to non-existent ConfigMap	Create the ConfigMap (app-config) or update envFrom to the correct name.
POST works but GET “Failed to fetch”	Stale API_BASE captured at import; CORS preflight	Use lazy getBase(); adopt the proxy Nginx pattern (same origin).
API CORS errors (if not using proxy)	Origin mismatch	Set CORS_ORIGIN to include the exact UI URL (e.g., http://127.0.0.1:64xxx). Then kubectl rollout restart deployment api.
9) Optional: Direct (non-proxy) mode

If you insist on calling the API tunnel directly from the browser:

Start the tunnel and keep window open:

minikube service api-service --url
# e.g. http://127.0.0.1:56143


Serve that in config.js (either via Nginx template or ConfigMap):

window.REACT_APP_API_URL = 'http://127.0.0.1:56143/api';


Ensure API CORS allows your web URL (CORS_ORIGIN: "http://127.0.0.1:<web-port>").

This mode works, but the proxy model is cleaner and more production-aligned.

10) Operations Cheat-Sheet
# Pods / services
kubectl get po -o wide
kubectl get svc

# Inspect web logs
kubectl logs deploy/web

# Verify runtime config from inside web
kubectl exec -it deploy/web -- curl -s http://localhost/config.js

# Verify in-cluster API
kubectl exec -it deploy/web -- curl -s http://api-service:4000/api/health

# Restart rollouts
kubectl rollout restart deployment api
kubectl rollout restart deployment web

# Open services (keep terminals open)
minikube service web --url
minikube service api-service --url

11) Key Takeaways

Prefer same-origin: Let Nginx proxy /api → api-service:4000. Zero CORS, no DNS exposure to the browser.

Runtime config: Load /config.js before the React bundle; in code, resolve API base lazily per request.

Windows + Docker driver: Always access through minikube service <svc> --url (localhost tunnels), not the Minikube VM IP.

If you want, I can also provide a ConfigMap-mounted nginx.conf (no image rebuild for config tweaks) or an Ingress template to unify URLs even further.
