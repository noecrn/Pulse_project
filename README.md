# IoT Biometric Sleep Tracker

![Platform](https://img.shields.io/badge/Platform-iOS%20%7C%20ESP32-blue)
![Language](https://img.shields.io/badge/Languages-Swift%20%7C%20Python-orange)
![Hardware](https://img.shields.io/badge/Hardware-Custom%20PCB-yellow)
![ML](https://img.shields.io/badge/AI-XGBoost%20%7C%20CoreML-green)

**An end-to-end IoT system for sleep analysis, featuring a custom-designed wearable, a secure BLE protocol, and on-device Machine Learning inference.**

> **Engineering Goal:** Bridge the gap between low-level hardware constraints and high-level software scalability by creating a full-stack pipeline from raw sensor acquisition to user-facing analytics.

---

## 🏗 System Architecture

The system follows a **data streaming architecture**. A low-power wearable device handles raw data acquisition, while a companion iOS application manages the heavy lifting: signal processing, ML inference, and visualization.

### High-Level Workflow
1.  **Sensing:** Accelerometer (FXOS8700) & Heart Rate sensor capture raw data.
2.  **Transmission:** ESP32 microcontroller streams data packets via Bluetooth Low Energy (BLE).
3.  **Processing:** iOS App aggregates data into rolling windows (Feature Engineering).
4.  **Inference:** A Core ML model (`PulseClassifier`) classifies the state as `Awake` or `Asleep`.

---

## 📂 Project Structure

```bash
├── Pulse app/             # iOS Companion App (Swift, SwiftUI, CoreML)
├── src/                   # Python ML Pipeline (Preprocessing, Training)
│   ├── data/              # Data loading and cleaning scripts
│   └── models/            # XGBoost & Random Forest training logic
├── notebooks/             # Jupyter Notebooks for EDA and prototyping
├── models/                # Serialized models (.joblib) and scalers
├── images/                # Schematics, PCB renders, and diagrams
└── firmware/              # (Implied) ESP32 C++ Firmware
```

---

## 🛠 Component Breakdown

### 1. Wearable Device (Hardware & Firmware)
**Role:** Raw Data Acquisition & Transmission
**Status:** Design complete, Ready for Fabrication.

* **Microcontroller:** **ESP32-WROOM-32E**. Selected for its dual-core architecture and deep sleep capabilities tailored for battery-operated IoT.
* **Sensors:**
    * **FXOS8700CQR1**: 6-axis Accelerometer/Magnetometer for precise motion tracking.
    * **Heart Rate Sensor**: Dedicated photoplethysmography (PPG) IC for pulse wave sensing.
* **Power Management**: USB-C charging circuit with dedicated voltage regulation (LDOs) to ensure stable power delivery.

#### 🔧 PCB Design & Architecture
The PCB utilizes a **two-sided component placement strategy** to optimize for size and signal integrity:

1.  **Top Side (Digital Domain):** Houses the ESP32, USB-C connector, and power management ICs. This isolates high-frequency digital noise.
2.  **Bottom Side (Analog/Sensor Domain):** Dedicated to the Heart Rate sensor to ensure direct skin contact and clean analog signal acquisition.

| 3D Render (Top) | Electronic Schematic |
| :---: | :---: |
| <img src="images/3D_PCB1_2025-10-19.png" width="400" alt="3D PCB Render"> | <img src="images/SCH_Schematic1_1-P1_2025-10-19.png" width="400" alt="Schematic"> |

> **Design Choice:** The physical separation of the analog sensor (Bottom) from the noisy digital logic (Top) minimizes signal interference, crucial for accurate biometric readings.

### 2. Machine Learning Pipeline (Data Science)

**Role:** Classification Algorithm

**Stack:** Python, Scikit-Learn, XGBoost

The core logic is a supervised learning model trained on the **MMASH dataset**.

1. **Feature Engineering**: Raw data is converted into **11 statistical features** over rolling windows (1, 5, and 15 minutes).
* *Examples:* `hr60_mean`, `vm15_std` (Vector Magnitude Standard Deviation).


2. **Model Selection**: Compared Logistic Regression, Random Forest, and XGBoost.
3. **Final Model**: **Tuned XGBoost Classifier**.
* **Performance**: 93% Accuracy, 0.96 F1-Score (Awake).
* **Optimization**: Hyperparameters tuned via `RandomizedSearchCV`.



### 3. iOS Companion App (Software)

**Role:** Client, Processor & Visualizer

**Stack:** Swift, SwiftUI, Charts, Core ML

* **Real-time BLE**: Handles scanning and parsing of the standard Heart Rate Service (UUID `0x180D`).
* **On-Device Inference**: The Python-trained XGBoost model was converted to `.mlpackage` to run locally on the iPhone, ensuring privacy and offline capability.
* **UI/UX**: "Deep Night" aesthetic with interactive, scrubbable charts.

<p align="center">
<img src="https://i.imgur.com/YtVjlis.png" alt="App Dashboard" width="300" />
</p>

---

## 🚀 Getting Started

### Prerequisites

* **Hardware**: Pulse PCB or ESP32 dev kit.
* **Software**: Xcode 15+, Python 3.9+.

### 1. Python Environment (ML Pipeline)

To reproduce the model training or explore the notebooks:

```bash
pip install -r requirements.txt
cd src/models
python train_final.py

```

### 2. iOS Application

1. Open `Pulse app/Pulse app.xcodeproj` in Xcode.
2. Ensure `PulseClassifier.mlpackage` is linked in the Build Phases.
3. Run on a physical iPhone (Bluetooth required).

---

## 📊 Performance Metrics

```text
              precision    recall  f1-score   support

   False           0.99      0.93      0.96      4893
    True           0.76      0.95      0.85      1182

accuracy                               0.93      6075

```

---

## 👤 Author

**Noé Cornu** Computer Engineering Student @ EPITA

[LinkedIn](https://www.google.com/search?q=https://www.linkedin.com/in/no%25C3%25A9-cornu-8599b8269/) | [GitHub](https://www.google.com/search?q=https://github.com/noecrn)
