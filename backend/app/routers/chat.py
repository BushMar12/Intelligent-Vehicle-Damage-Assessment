from fastapi import APIRouter, Depends, HTTPException
from sqlalchemy.ext.asyncio import AsyncSession
from sqlalchemy.future import select
from pydantic import BaseModel
from openai import AsyncOpenAI

from app.db.database import get_db
from app.db.models import Assessment
from app.config import settings

router = APIRouter(prefix="/chat", tags=["Chat"])

class ChatRequest(BaseModel):
    assessment_id: str
    message: str

class ChatResponse(BaseModel):
    success: bool
    response: str
    assessment_id: str

@router.post("/", response_model=ChatResponse)
async def chat_with_bot(req: ChatRequest, db: AsyncSession = Depends(get_db)):
    result = await db.execute(select(Assessment).filter(Assessment.id == req.assessment_id))
    assessment = result.scalar_one_or_none()
    
    if not assessment:
        raise HTTPException(status_code=404, detail="Assessment not found.")
        
    # Using local Ollama default configuration or overrides
    base_url = getattr(settings, "LLM_BASE_URL", "http://localhost:11434/v1") 
    api_key = getattr(settings, "LLM_API_KEY", "ollama")
    model_name = getattr(settings, "LLM_MODEL", "qwen2.5")
    
    client = AsyncOpenAI(base_url=base_url, api_key=api_key)
    
    if not assessment.chat_history:
        assessment.chat_history = []
        
    user_message = {"role": "user", "content": req.message}
    
    context_str = (
        f"You are an AI assistant for a vehicle damage assessment tool. "
        f"The current assessment JSON report is: {assessment.report_json}\n"
        f"Cost JSON: {assessment.cost_estimation_json}\n"
        f"Answer the user's question based on this data."
    )
    
    messages = [
        {"role": "system", "content": context_str},
    ]
    
    # Load previous history
    for msg in assessment.chat_history:
        role = msg.get("role", "user")
        # In case old history formats leak, fallback correctly.
        content = msg.get("content", msg.get("parts", [{}])[0].get("text", ""))
        messages.append({"role": role, "content": content})
        
    messages.append(user_message)
    
    try:
        response = await client.chat.completions.create(
            model=model_name,
            messages=messages,
            timeout=30.0
        )
        bot_text = response.choices[0].message.content
        
        new_history = list(assessment.chat_history)
        new_history.append(user_message)
        new_history.append({"role": "assistant", "content": bot_text})
        
        assessment.chat_history = new_history
        db.add(assessment)
        await db.commit()
        
        return ChatResponse(success=True, response=bot_text, assessment_id=req.assessment_id)
    except Exception as e:
        error_msg = f"LLM API error: {str(e)}"
        if "Connection" in error_msg or "connect" in error_msg.lower():
            error_msg += "\\nMake sure Ollama is running if you are using local Qwen!"
        raise HTTPException(status_code=500, detail=error_msg)
