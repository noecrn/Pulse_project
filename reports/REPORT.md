# 📈 Sleep Detection Model: Final Report

## 1. Executive Summary

This project successfully developed a machine learning pipeline to detect sleep from sensor data. The final model is a **Tuned XGBoost Classifier** that achieves an **F1-score of 0.85** for the positive class (sleep) on a held-out test set, with an overall accuracy of 93%.

The key finding of this project is that **feature engineering was the most critical step** for achieving high performance. The introduction of rolling-window statistics dramatically improved the model's ability to distinguish sleep from quiet wakefulness.

## 2. Methodology

The project followed a standard machine learning pipeline:
1.  **Data Preprocessing**: Raw RR (heart rate) and actigraphy (movement) data for each user were loaded, cleaned, and merged into a single time-series.
2.  **Feature Engineering**: The initial features were statistical aggregations (mean, std, sum) over 60-second windows. To improve performance, **rolling statistics** (mean and standard deviation over 5 and 15-minute windows) were added to provide the model with temporal context.
3.  **Model Evaluation**: Several models were compared, including Logistic Regression, Random Forest, and XGBoost. The primary metric for success was the F1-score for the minority class (sleep) due to the imbalanced nature of the dataset.
4.  **Hyperparameter Tuning**: `RandomizedSearchCV` was used to find the optimal parameters for the best-performing algorithm.

## 3. Model Comparison

The addition of engineered features significantly boosted the performance of all models. The final comparison on the enriched dataset is as follows:

| Model                | F1-Score (Sleep) |
| -------------------- | ---------------- |
| **XGBoost (Tuned)** | **0.85** |
| RandomForest (Default) | 0.84             |
| LogisticRegression   | 0.75             |

## 4. Final Model Performance

The champion model, a tuned XGBoost classifier, produced the following detailed results on the final test set.

```
              precision    recall  f1-score   support

   False           0.99      0.93      0.96      4893
    True           0.76      0.95      0.85      1182

accuracy                               0.93      6075

macro avg          0.87      0.94      0.90      6075
weighted avg       0.94      0.93      0.94      6075
```

The model demonstrates excellent recall (0.95), meaning it successfully identifies 95% of all actual sleep periods.

## 5. Conclusion

The project successfully delivered a high-performing sleep detection model. The process underscored the importance of an iterative approach, starting with a simple baseline and methodically improving it. The clear takeaway is that for time-series classification, providing contextual features that capture trends over time is often more impactful than extensive algorithm tuning alone.