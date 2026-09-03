import uuid
import asyncio
from contextlib import asynccontextmanager
from fastapi import FastAPI, Request, status
from fastapi.responses import JSONResponse
from fastapi.middleware.cors import CORSMiddleware
from server.app.config import settings
from server.app.models.schemas import ErrorResponse, ErrorDetail
from server.app.services.sweeper import cooling_sweeper
from server.app.api.v1.auth import router as auth_router
from server.app.api.v1.onboarding import router as onboarding_router
from server.app.api.v1.accounts import router as accounts_router
from server.app.api.v1.transactions import router as transactions_router
from server.app.api.v1.payees import router as payees_router
from server.app.api.v1.transfers import router as transfers_router
from server.app.api.v1.trusted_contacts import router as tc_router
from server.app.api.v1.tc_actions import router as tc_actions_router
from server.app.api.v1.voice import router as voice_router
from server.app.api.v1.admin import router as admin_router
from server.app.api.v1.websocket import router as ws_router


@asynccontextmanager
async def lifespan(app: FastAPI):
    # Startup: launch cooling sweeper periodic loop
    sweeper_task = asyncio.create_task(cooling_sweeper.start_loop())
    yield
    # Shutdown
    cooling_sweeper.stop()
    sweeper_task.cancel()


app = FastAPI(
    title="VaniGuard API",
    description="Voice-First Secure Banking Platform with Real-Time Coercion Detection and Fraud Intervention",
    version="1.0.0",
    lifespan=lifespan
)

# CORS Middleware
app.add_middleware(
    CORSMiddleware,
    allow_origins=["*"],
    allow_credentials=True,
    allow_methods=["*"],
    allow_headers=["*"],
)


# Request-ID Correlation Middleware
@app.middleware("http")
async def request_id_middleware(request: Request, call_next):
    request_id = request.headers.get("X-Request-Id", str(uuid.uuid4()))
    request.state.request_id = request_id
    response = await call_next(request)
    response.headers["X-Request-Id"] = request_id
    return response


# Global Exception Handler formatting into the bilingual error contract
@app.exception_handler(Exception)
async def global_exception_handler(request: Request, exc: Exception):
    request_id = getattr(request.state, "request_id", str(uuid.uuid4()))
    err = ErrorDetail(
        code="INTERNAL_SERVER_ERROR",
        message=str(exc),
        user_message_en="A banking security service error occurred. Please try again or speak to your trusted contact.",
        user_message_hi="बैंकिंग सुरक्षा सेवा में त्रुटि आई। कृपया पुनः प्रयास करें या अपने विश्वसनीय संपर्क से बात करें।",
        request_id=request_id
    )
    return JSONResponse(
        status_code=status.HTTP_500_INTERNAL_SERVER_ERROR,
        content=ErrorResponse(error=err).model_dump()
    )


# Health Check Endpoints
@app.get("/health")
@app.get("/api/v1/health")
async def health_check():
    return {
        "status": "healthy",
        "service": "vaniguard-backend",
        "version": "1.0.0",
        "sweeper_active": cooling_sweeper._running
    }


# Include Routers under /api/v1
api_v1_prefix = "/api/v1"
app.include_router(auth_router, prefix=api_v1_prefix)
app.include_router(onboarding_router, prefix=api_v1_prefix)
app.include_router(accounts_router, prefix=api_v1_prefix)
app.include_router(transactions_router, prefix=api_v1_prefix)
app.include_router(payees_router, prefix=api_v1_prefix)
app.include_router(transfers_router, prefix=api_v1_prefix)
app.include_router(tc_router, prefix=api_v1_prefix)
app.include_router(tc_actions_router, prefix=api_v1_prefix)
app.include_router(voice_router, prefix=api_v1_prefix)
app.include_router(admin_router, prefix=api_v1_prefix)
app.include_router(ws_router)
