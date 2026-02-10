# src/visualization/plot.py

import pandas as pd
import plotly.graph_objects as go
import matplotlib.pyplot as plt
import seaborn as sns
from pathlib import Path
from sklearn.metrics import confusion_matrix, roc_curve, auc

def plot_user_hr(user_id: str):
    """
    Plot heart rate (hr_mean) over time for a given user.
    """
    path = Path(f"../data/processed/{user_id}.csv")
    if not path.exists():
        print(f"❌ File not found: {path}")
        return

    df = pd.read_csv(path, parse_dates=["timestamp"])

    fig = go.Figure()
    fig.add_trace(go.Scatter(
        x=df["timestamp"],
        y=df["bpm"],
        mode="lines",
        name="Heart Rate (bpm)",
        line=dict(color="royalblue")
    ))

    fig.update_layout(
        title=f"Heart Rate over Time – {user_id}",
        xaxis_title="Timestamp",
        yaxis_title="Heart Rate (bpm)",
        hovermode="x unified"
    )

    fig.show()

def plot_confusion_matrix(y_true, y_pred, title="Confusion Matrix"):
    cm = confusion_matrix(y_true, y_pred)
    plt.figure(figsize=(5, 4))
    sns.heatmap(cm, annot=True, fmt="d", cmap="Blues")
    plt.xlabel("Predicted")
    plt.ylabel("Actual")
    plt.title(title)
    plt.show()

def plot_roc_curve(y_true, y_score, title="ROC Curve"):
    fpr, tpr, _ = roc_curve(y_true, y_score)
    roc_auc = auc(fpr, tpr)
    plt.figure(figsize=(6, 4))
    plt.plot(fpr, tpr, label=f"AUC = {roc_auc:.2f}")
    plt.plot([0, 1], [0, 1], linestyle="--", color="gray")
    plt.xlabel("False Positive Rate")
    plt.ylabel("True Positive Rate")
    plt.title(title)
    plt.legend()
    plt.grid(True)
    plt.show()