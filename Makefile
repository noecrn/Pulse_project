.PHONY: prepare train eval clean

prepare:
	@echo "🔧 Preprocessing data and generating features..."
	python main.py prepare

train:
	@echo "🏋️ Training model on all users..."
	python main.py train

eval:
	@echo "📈 Evaluating model..."
	python main.py eval

# Define the feature file as a variable
FEATURE_FILE = data/features/all_users.csv

# The train_final target now DEPENDS on the feature file
train_final: $(FEATURE_FILE)
	@echo "📦 Training final model on all data for production..."
	python main.py train_final

# Add a rule to tell 'make' how to create the feature file
$(FEATURE_FILE):
	@echo "🔧 Feature file not found. Running preparation step..."
	make prepare

clean:
	@echo "🧹 Cleaning processed and features data..."
	rm -rf data/processed/*.csv
	rm -f data/features/all_users.csv