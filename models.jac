"""One model pool for the whole app.

Hosted (Jac Hammer): set OLLAMA_API_KEY and/or GEMINI_API_KEY as environment variables.
Local dev: falls through to the local Ollama daemon.
"""
import os;
import from jaclang.byllm.lib { Model, ModelPool }

def build_pool -> ModelPool {
    models: list[Model] = [];
    ollama_key = os.getenv("OLLAMA_API_KEY", "");
    if ollama_key {
        models.append(Model(model_name="ollama_chat/gemma4:31b", api_key=ollama_key, config={"base_url": "https://ollama.com"}));
    }
    if os.getenv("GEMINI_API_KEY", "") {
        models.append(Model(model_name="gemini/gemini-3.5-flash"));
    }
    models.append(Model(model_name="ollama_chat/gemma4:31b-cloud"));
    models.append(Model(model_name="ollama_chat/gpt-oss:120b-cloud"));
    models.append(Model(model_name="ollama_chat/llama3.1"));
    return ModelPool(models=models, strategy="fallback");
}

glob llm = build_pool();
