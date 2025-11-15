"""
Nigerian Maize Yield Prediction API
Predicts maize yield based on agricultural parameters using a trained Random Forest model
"""

from fastapi import FastAPI, HTTPException
from fastapi.middleware.cors import CORSMiddleware
from pydantic import BaseModel, Field, field_validator
import joblib
import pandas as pd
from typing import List
import os

# Initialize FastAPI app
app = FastAPI(
    title="Nigerian Maize Yield Prediction API",
    description="API for predicting maize yields in Nigeria based on state, season, year, farm area, and quality grade",
    version="1.0.0",
    docs_url="/docs",
    redoc_url="/redoc"
)

# CORS Middleware Configuration
# Allows cross-origin requests from any origin (can be restricted to specific domains)
app.add_middleware(
    CORSMiddleware,
    allow_origins=["*"],  # In production, replace with specific origins like ["https://yourdomain.com"]
    allow_credentials=True,
    allow_methods=["*"],  # Allows all HTTP methods (GET, POST, etc.)
    allow_headers=["*"],  # Allows all headers
)

# Load model and preprocessors from parent directory
# Construct path relative to this file's location
BASE_DIR = os.path.dirname(os.path.abspath(__file__))
PARENT_DIR = os.path.dirname(BASE_DIR)

try:
    model = joblib.load(os.path.join(PARENT_DIR, 'best_model.pkl'))
    scaler = joblib.load(os.path.join(PARENT_DIR, 'scaler.pkl'))
    le_state = joblib.load(os.path.join(PARENT_DIR, 'le_state.pkl'))
    le_grade = joblib.load(os.path.join(PARENT_DIR, 'le_grade.pkl'))
    feature_names = joblib.load(os.path.join(PARENT_DIR, 'feature_names.pkl'))
    print("Model and preprocessors loaded successfully!")
except Exception as e:
    print(f"Error loading model files: {e}")
    raise

# Get valid states and grades from encoders
VALID_STATES = le_state.classes_.tolist()
VALID_GRADES = le_grade.classes_.tolist()

# Pydantic Model for Input Validation with Constraints
class YieldPredictionRequest(BaseModel):
    """
    Input model for maize yield prediction with data type and range constraints
    """
    state: str = Field(
        description="Nigerian state name (e.g., 'Kano', 'Lagos', 'Kaduna')",
        examples=["Kano"]
    )
    season: str = Field(
        description="Season type: 'wet' or 'dry'",
        examples=["wet"]
    )
    year: int = Field(
        ge=2000,
        le=2030,
        description="Year of cultivation (between 2000 and 2030)",
        examples=[2023]
    )
    area_ha: float = Field(
        gt=0.0,
        le=1000.0,
        description="Farm area in hectares (must be positive, max 1000 ha)",
        examples=[5.0]
    )
    quality_grade: str = Field(
        description="Quality grade of the farm/seed (e.g., 'A', 'B', 'C')",
        examples=["A"]
    )

    @field_validator('season')
    @classmethod
    def validate_season(cls, v: str) -> str:
        """Validate season is either 'wet' or 'dry'"""
        v_lower = v.lower()
        if v_lower not in ['wet', 'dry']:
            raise ValueError("Season must be either 'wet' or 'dry'")
        return v_lower

    @field_validator('state')
    @classmethod
    def validate_state(cls, v: str) -> str:
        """Validate state exists in the training data"""
        if v not in VALID_STATES:
            raise ValueError(f"State '{v}' not recognized. Available states: {', '.join(VALID_STATES[:10])}... (and {len(VALID_STATES)-10} more)")
        return v

    @field_validator('quality_grade')
    @classmethod
    def validate_grade(cls, v: str) -> str:
        """Validate quality grade exists in the training data"""
        if v not in VALID_GRADES:
            raise ValueError(f"Quality grade '{v}' not recognized. Available grades: {', '.join(VALID_GRADES)}")
        return v

    class Config:
        json_schema_extra = {
            "example": {
                "state": "Abia",
                "season": "wet",
                "year": 2020,
                "area_ha": 5.0,
                "quality_grade": "Grade A"
            }
        }


# Pydantic Model for Response
class YieldPredictionResponse(BaseModel):
    """
    Response model for maize yield prediction
    """
    predicted_yield: float = Field(
        ...,
        description="Predicted maize yield in tonnes per hectare"
    )
    input_parameters: dict = Field(
        ...,
        description="Echo of input parameters used for prediction"
    )
    model_used: str = Field(
        default="Random Forest",
        description="Name of the machine learning model used"
    )
    unit: str = Field(
        default="tonnes/hectare",
        description="Unit of measurement for the prediction"
    )

    class Config:
        json_schema_extra = {
            "example": {
                "predicted_yield": 3.45,
                "input_parameters": {
                    "state": "Abia",
                    "season": "wet",
                    "year": 2020,
                    "area_ha": 5.0,
                    "quality_grade": "Grade A"
                },
                "model_used": "Random Forest",
                "unit": "tonnes/hectare"
            }
        }


# Root endpoint
@app.get("/", tags=["Root"])
async def root():
    """
    Root endpoint - Welcome message and API information
    """
    return {
        "message": "Welcome to Nigerian Maize Yield Prediction API",
        "description": "This API predicts maize yields based on agricultural parameters",
        "documentation": "/docs",
        "health_check": "/health",
        "prediction_endpoint": "/predict (POST)"
    }


# Health check endpoint
@app.get("/health", tags=["Health"])
async def health_check():
    """
    Health check endpoint to verify API is running
    """
    return {
        "status": "healthy",
        "model_loaded": model is not None,
        "available_states": len(VALID_STATES),
        "available_grades": len(VALID_GRADES)
    }


# Main prediction endpoint
@app.post("/predict", response_model=YieldPredictionResponse, tags=["Prediction"])
async def predict_yield(request: YieldPredictionRequest):
    """
    Predict maize yield based on input parameters
    
    Parameters:
    - **state**: Nigerian state name
    - **season**: Season type (wet or dry)
    - **year**: Year of cultivation (2000-2030)
    - **area_ha**: Farm area in hectares (0-1000)
    - **quality_grade**: Quality grade
    
    Returns:
    - Predicted yield in tonnes per hectare
    """
    try:
        # Encode state
        state_encoded = le_state.transform([request.state])[0]
        print(f"State encoded: {request.state} -> {state_encoded}")
        
        # Encode season (already validated to be 'wet' or 'dry')
        is_wet = 1 if request.season == 'wet' else 0
        print(f"Season encoded: {request.season} -> {is_wet}")
        
        # Encode quality grade
        grade_encoded = le_grade.transform([request.quality_grade])[0]
        print(f"Grade encoded: {request.quality_grade} -> {grade_encoded}")
        
        # Create interaction feature
        area_wet_interaction = request.area_ha * is_wet
        
        # Create input DataFrame with exact feature order
        input_data = pd.DataFrame({
            'state': [state_encoded],
            'is_wet': [is_wet],
            'year': [request.year],
            'area_ha': [request.area_ha],
            'quality_grade': [grade_encoded],
            'area_wet_interaction': [area_wet_interaction]
        })
        
        print(f"Feature names from model: {feature_names}")
        print(f"Input data columns: {input_data.columns.tolist()}")
        print(f"Input data:\n{input_data}")
        
        # Reorder to match training feature order
        input_data = input_data[feature_names]
        
        # Make prediction (Random Forest doesn't need scaling)
        prediction = model.predict(input_data)[0]
        print(f"Raw prediction: {prediction}")
        
        # Round to 2 decimal places
        predicted_yield = round(float(prediction), 2)
        
        # Return response
        return YieldPredictionResponse(
            predicted_yield=predicted_yield,
            input_parameters={
                "state": request.state,
                "season": request.season,
                "year": request.year,
                "area_ha": request.area_ha,
                "quality_grade": request.quality_grade
            },
            model_used="Random Forest",
            unit="tonnes/hectare"
        )
        
    except Exception as e:
        import traceback
        error_details = traceback.format_exc()
        print(f"ERROR: {error_details}")
        raise HTTPException(
            status_code=500,
            detail=f"Prediction failed: {str(e)}"
        ) from e


# Batch prediction endpoint (bonus feature)
@app.post("/predict/batch", tags=["Prediction"])
async def predict_yield_batch(requests: List[YieldPredictionRequest]):
    """
    Predict maize yield for multiple inputs at once
    
    Accepts a list of prediction requests and returns a list of predictions
    """
    try:
        predictions = []
        for request in requests:
            # Reuse the single prediction logic
            result = await predict_yield(request)
            predictions.append(result)
        
        return {
            "count": len(predictions),
            "predictions": predictions
        }
        
    except Exception as e:
        raise HTTPException(
            status_code=500,
            detail=f"Batch prediction failed: {str(e)}"
        ) from e


# Get available states endpoint
@app.get("/states", tags=["Information"])
async def get_available_states():
    """
    Get list of all available Nigerian states in the model
    """
    return {
        "count": len(VALID_STATES),
        "states": sorted(VALID_STATES)
    }


# Get available quality grades endpoint
@app.get("/grades", tags=["Information"])
async def get_available_grades():
    """
    Get list of all available quality grades in the model
    """
    return {
        "count": len(VALID_GRADES),
        "grades": sorted(VALID_GRADES)
    }


# Run the application
if __name__ == "__main__":
    import uvicorn
    uvicorn.run(app, host="0.0.0.0", port=8000)
