#!/bin/bash
set -e

echo "🐍 Bootstrapping Infinity-X One Swarm Python Environment..."
PROJECT_DIR="$HOME/infinity-x-one-swarm"
VENV_DIR="$PROJECT_DIR/.venv"

# 1️⃣ Create venv if missing
if [ ! -d "$VENV_DIR" ]; then
  echo "🧱 Creating virtual environment..."
  python3 -m venv "$VENV_DIR"
else
  echo "✅ Virtual environment already exists."
fi

# 2️⃣ Activate environment
echo "🔗 Activating virtual environment..."
source "$VENV_DIR/bin/activate"

# 3️⃣ Upgrade pip and setuptools
echo "⚙️ Upgrading pip and build tools..."
pip install --upgrade pip setuptools wheel

# 4️⃣ Install required dependencies
echo "📦 Installing required Python packages..."
pip install \
  faiss-cpu \
  numpy \
  fastapi \
  uvicorn \
  google-cloud-firestore \
  google-cloud-storage \
  google-cloud-pubsub \
  google-cloud-run \
  pydantic \
  requests \
  rich \
  typer[all]

# 5️⃣ Save activation hook (optional)
if ! grep -q "source $VENV_DIR/bin/activate" ~/.bashrc; then
  echo "💾 Adding auto-activation to ~/.bashrc"
  echo "source $VENV_DIR/bin/activate" >> ~/.bashrc
fi

echo "✅ Environment bootstrap complete!"
echo "🧠 To activate manually: source $VENV_DIR/bin/activate"
echo "🚀 You can now run any bootstrap (e.g. hydration/vector/secret sync)"
