"""FoodVision AI Backend - Jac powered.

Endpoints:
  POST /function/health          - Health check (public)
  POST /function/analyze_meal    - Qwen3-VL proxy (public)
  POST /user/register            - Register (built-in)
  POST /user/login               - Login (built-in)
  POST /function/get_profile     - Get user profile (auth required)
  POST /function/update_profile  - Update user profile (auth required)
  POST /function/save_meal       - Save meal entry (auth required)
  POST /function/get_meals       - Get meal history (auth required)
"""

import from dotenv { load_dotenv }
import from os { getenv }
import from requests { post as http_post }
import from json { dumps as json_dumps, loads as json_loads }
import from re { sub as re_sub, search as re_search }
import from datetime { datetime as dt_cls }



# ── Data Model (Graph Nodes) ──────────────────────────────────

node UserProfile {
    has dietary_restrictions: list = [],
        allergies: list = [],
        cuisine_preferences: list = [],
        flavor_preferences: list = [],
        cooking_skill_level: str = "Intermediate",
        available_equipment: list = [],
        nutritional_goals: list = [],
        disliked_foods: list = [],
        other_preferences: list = [],
        display_name: str = "",
        habits: str = "",
        updated_at: str = "";
}

node MealEntry {
    has dish_name: str = "",
        reason: str = "",
        key_ingredients: list = [],
        substitutions: list = [],
        nutrition_analysis: dict = {},
        preparation_overview: list = [],
        user_message: str = "",
        created_at: str = "";
}


# ── Public Endpoints ──────────────────────────────────────────

"""Health check."""
def:pub health() -> dict {
    return {"status": "ok", "service": "FoodVision AI Backend"};
}

"""Analyze a food image using Qwen3-VL-32B via OpenRouter (public, no auth needed)."""
def:pub analyze_meal(image_base64: str = "", message: str = "", user_profile: dict = {}) -> dict {
    load_dotenv();
    api_key = getenv("OPENROUTER_API_KEY", "");

    system_prompt = "\n".join([
        "You are a professional food and nutrition AI assistant.",
        "You MUST respond with valid JSON only (no markdown, no code fences, no extra text).",
        "The JSON must have exactly this structure:",
        '{"updated_user_profile":{"dietary_restrictions":[],"allergies":[],"cuisine_preferences":[],"flavor_preferences":[],"cooking_skill_level":"string","available_equipment":[],"nutritional_goals":[],"disliked_foods":[]},"recommendation":{"dish_name":"string","reason_for_recommendation":"string","key_ingredients":[],"substitutions":[],"nutrition_analysis":{"estimated_daily_needs":{"calories":"string","protein":"string","carbohydrates":"string","fat":"string","fiber":"string"},"ingredient_nutrition_summary":"string","nutritional_balance_assessment":"string","suggested_nutritional_improvements":"string"},"preparation_overview":["Step 1: ...","Step 2: ..."]}}',
        "",
        "Current user profile: " + json_dumps(user_profile),
        "Analyze the food image, identify what is in it, and provide a personalized recipe recommendation.",
        "Update the user profile based on any new preferences mentioned in the user message.",
        "IMPORTANT: Return ONLY the JSON object, nothing else."
    ]);

    user_msg = message if message else "Analyze this food image and suggest a recipe based on what you see and my preferences.";

    messages = [
        {"role": "system", "content": system_prompt},
        {
            "role": "user",
            "content": [
                {"type": "image_url", "image_url": {"url": image_base64}},
                {"type": "text", "text": user_msg}
            ]
        }
    ];

    resp = http_post(
        "https://openrouter.ai/api/v1/chat/completions",
        headers={
            "Authorization": "Bearer " + api_key,
            "Content-Type": "application/json",
            "HTTP-Referer": "https://foodvision-ai.app",
            "X-OpenRouter-Title": "FoodVision AI"
        },
        json={
            "model": "qwen/qwen3-vl-32b-instruct",
            "messages": messages,
            "max_tokens": 4096,
            "temperature": 0.7
        },
        timeout=120
    );

    resp_json = resp.json();
    if resp.status_code != 200 {
        return {"error": "OpenRouter API error " + str(resp.status_code), "detail": str(resp_json)};
    }

    content = str(resp_json["choices"][0]["message"]["content"]);
    content = re_sub("^```(?:json)?\\s*", "", content.strip());
    content = re_sub("\\s*```$", "", content.strip());

    found = re_search("\\{[\\s\\S]*\\}", content);
    if found {
        return json_loads(found.group(0));
    }
    return {"error": "Could not parse JSON from model response", "raw": content};
}


# ── Private Endpoints (require JWT auth) ──────────────────────

"""Get the current user's profile."""
def:priv get_profile() -> dict {
    profiles = [root()-->][?:UserProfile];
    if not profiles {
        root() ++> UserProfile();
        profiles = [root()-->][?:UserProfile];
    }
    p = profiles[0];
    return {
        "display_name": p.display_name,
        "habits": p.habits,
        "dietary_restrictions": p.dietary_restrictions,
        "allergies": p.allergies,
        "cuisine_preferences": p.cuisine_preferences,
        "flavor_preferences": p.flavor_preferences,
        "cooking_skill_level": p.cooking_skill_level,
        "available_equipment": p.available_equipment,
        "nutritional_goals": p.nutritional_goals,
        "disliked_foods": p.disliked_foods,
        "other_preferences": p.other_preferences,
        "updated_at": p.updated_at
    };
}

"""Update the current user's profile."""
def:priv update_profile(
    display_name: str = "",
    habits: str = "",
    dietary_restrictions: list = [],
    allergies: list = [],
    cuisine_preferences: list = [],
    flavor_preferences: list = [],
    cooking_skill_level: str = "",
    available_equipment: list = [],
    nutritional_goals: list = [],
    disliked_foods: list = [],
    other_preferences: list = []
) -> dict {
    profiles = [root()-->][?:UserProfile];
    if not profiles {
        root() ++> UserProfile();
        profiles = [root()-->][?:UserProfile];
    }
    p = profiles[0];
    if display_name { p.display_name = display_name; }
    if habits { p.habits = habits; }
    if dietary_restrictions { p.dietary_restrictions = dietary_restrictions; }
    if allergies { p.allergies = allergies; }
    if cuisine_preferences { p.cuisine_preferences = cuisine_preferences; }
    if flavor_preferences { p.flavor_preferences = flavor_preferences; }
    if cooking_skill_level { p.cooking_skill_level = cooking_skill_level; }
    if available_equipment { p.available_equipment = available_equipment; }
    if nutritional_goals { p.nutritional_goals = nutritional_goals; }
    if disliked_foods { p.disliked_foods = disliked_foods; }
    if other_preferences { p.other_preferences = other_preferences; }
    p.updated_at = str(dt_cls.now());
    return {"success": True, "updated_at": p.updated_at};
}

"""Save a meal entry for the current user."""
def:priv save_meal(
    dish_name: str = "",
    reason: str = "",
    key_ingredients: list = [],
    substitutions: list = [],
    nutrition_analysis: dict = {},
    preparation_overview: list = [],
    user_message: str = ""
) -> dict {
    ts = str(dt_cls.now());
    meal = MealEntry(
        dish_name=dish_name,
        reason=reason,
        key_ingredients=key_ingredients,
        substitutions=substitutions,
        nutrition_analysis=nutrition_analysis,
        preparation_overview=preparation_overview,
        user_message=user_message,
        created_at=ts
    );
    root() ++> meal;
    return {"success": True, "created_at": ts};
}

"""Get all meal entries for the current user."""
def:priv get_meals() -> list {
    meals = [root()-->][?:MealEntry];
    result: list = [];
    for m in meals {
        result.append({
            "dish_name": m.dish_name,
            "reason": m.reason,
            "key_ingredients": m.key_ingredients,
            "substitutions": m.substitutions,
            "nutrition_analysis": m.nutrition_analysis,
            "preparation_overview": m.preparation_overview,
            "user_message": m.user_message,
            "created_at": m.created_at
        });
    }
    return result;
}
