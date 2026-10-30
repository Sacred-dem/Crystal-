from fastapi import APIRouter

router = APIRouter()


@router.get("")
def health():
    return {"status": "ok", "mode": "hybrid", "version": "0.1.0"}
