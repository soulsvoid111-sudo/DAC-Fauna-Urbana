from fastapi import FastAPI

app = FastAPI()


@app.get("/")
def root():
    return {"message": "Fauna Urbana API funcionando!"}