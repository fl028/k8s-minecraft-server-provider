from fastapi import FastAPI
from routers.servers import router 

app = FastAPI()
app.include_router(router, prefix="/api")