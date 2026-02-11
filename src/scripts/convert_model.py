import joblib
import numpy as np
import coremltools as ct
from sklearn.pipeline import Pipeline
from hummingbird.ml import convert

# 1. Load your artifacts
print("Chargement du scaler et du modèle...")
scaler = joblib.load("models/production_scaler.joblib")
model = joblib.load("models/production_model.joblib")

# 2. Create the Pipeline
# This bundles scaling and prediction together
pipeline = Pipeline([
    ("scaler", scaler),
    ("model", model)
])

# 3. Define sample input (1 row, 11 features)
# Use the same number of features used during training
sample_input = np.zeros((1, 11), dtype=np.float32)

def save_coreml_model(model, mlmodel_path="PulseClassifier.mlmodel", mlpackage_path="PulseClassifier.mlpackage"):
    try:
        model.save(mlmodel_path)
        print(f"Succès ! Modèle sauvegardé : {mlmodel_path}")
    except Exception as e:
        msg = str(e)
        if "extension must be .mlpackage" in msg or "mlpackage" in msg:
            model.save(mlpackage_path)
            print(f"Succès ! Modèle ML Program sauvegardé : {mlpackage_path}")
        else:
            raise

# 1) Preferred path: Hummingbird -> PyTorch -> Core ML
print("Étape 1: Essai de conversion du pipeline vers PyTorch (via Hummingbird)...")
coreml_model = None
try:
    hb_torch = convert(pipeline, "pytorch", sample_input, extra_config={"n_features": 11})
    torch_model = hb_torch.model
    import torch
    example_input = torch.from_numpy(sample_input.astype(np.float32))
    try:
        traced = torch.jit.trace(torch_model, example_input)
    except Exception:
        traced = torch.jit.script(torch_model)
    coreml_model = ct.convert(
        traced,
        source='pytorch',
        inputs=[ct.TensorType(shape=tuple(example_input.shape))],
        minimum_deployment_target=ct.target.iOS16
    )
except Exception as e:
    # 2) Fallback: export ONNX and instruct user for conversion
    print(f"PyTorch conversion failed: {e}")
    print("Fallback: export du pipeline en ONNX (fichier enregistré), puis convertissez manuellement en Core ML.")
    hb_onnx = convert(pipeline, "onnx", sample_input, extra_config={"n_features": 11})
    onnx_model = hb_onnx.model
    import onnx
    onnx_filename = "PulseClassifier.onnx"
    onnx.save_model(onnx_model, onnx_filename)
    raise RuntimeError(
        "PyTorch conversion failed and automatic ONNX->CoreML conversion is disabled in this cleaned script.\n"
        f"ONNX model saved to: {onnx_filename}\n"
        "To convert ONNX->CoreML, install a converter (e.g. `pip install onnx-coreml`) or use a coremltools build with ONNX support, "
        "then run the appropriate conversion command."
    )

# 3) Set metadata and save
coreml_model.author = "Pulse Team"
coreml_model.license = "Internal Use"
coreml_model.short_description = "XGBoost Sleep Detector (0: Awake, 1: Sleep)"

save_coreml_model(coreml_model)