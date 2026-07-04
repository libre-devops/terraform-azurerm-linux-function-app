"""A FastAPI hello world served through Azure Functions' ASGI bridge.

The Functions host hands every HTTP request to FastAPI (see host.json, which clears the host's
own /api route prefix so FastAPI owns the full path), so this file is plain FastAPI: add routers,
dependencies, and models exactly as you would anywhere else.

Two things worth knowing about how this renders in the Azure portal:

- The ASGI bridge registers ONE catch-all function (route {*route}, shown as *route in the
  portal), so the whole app appears as a single function: FastAPI owns the routing table and the
  Functions host is just the front door. If you want one portal entry per endpoint, write native
  @app.route functions instead of the bridge.
- Application logs come from the stdlib logging module: the Python worker forwards these records
  to the host, which streams them live (Code + Test, Log stream) and ships them to Application
  Insights as traces correlated with the invocation. An app that never logs shows only host
  scaffolding, so this one logs every request through the middleware below.
"""

import logging
import time

import azure.functions as func
from fastapi import FastAPI, Request

logger = logging.getLogger("app")

fastapi_app = FastAPI(title="Libre DevOps hello world")


@fastapi_app.middleware("http")
async def log_requests(request: Request, call_next):
    started = time.perf_counter()
    response = await call_next(request)
    elapsed_ms = (time.perf_counter() - started) * 1000
    logger.info("%s %s responded %s in %.1fms", request.method, request.url.path, response.status_code, elapsed_ms)
    return response


@fastapi_app.get("/api/hello")
async def hello():
    logger.info("hello endpoint invoked")
    return {"message": "Hello from FastAPI on Azure Functions Flex Consumption"}


@fastapi_app.get("/api/health")
async def health():
    return {"status": "ok"}


app = func.AsgiFunctionApp(app=fastapi_app, http_auth_level=func.AuthLevel.ANONYMOUS)
