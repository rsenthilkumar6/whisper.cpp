#!/bin/bash
set -e  # exit on first error

# ------------------------------
# 1. Build whisper.cpp with Metal and Core ML
# ------------------------------
echo "🔨 Building whisper.cpp (Metal + Core ML)..."
cmake -B build -DGGML_METAL=ON -DWHISPER_COREML=1 -DWHISPER_BUILD_EXAMPLES=ON -DCMAKE_BUILD_TYPE=Release
cmake --build build -j "$(sysctl -n hw.physicalcpu)" --config Release

# ------------------------------
# 2. Set up Python virtual environment
# ------------------------------
if [ ! -d ".venv" ]; then
    echo "🐍 Creating Python virtual environment..."
    python3 -m venv .venv
    # Use the venv's pip directly
    .venv/bin/pip install --upgrade pip
    .venv/bin/pip install torch openai-whisper coremltools ane_transformers
else
    echo "✅ Virtual environment already exists."
fi

# Define a helper to run Python scripts inside the venv
PYTHON=".venv/bin/python3"

# ------------------------------
# 3. Ensure Whisper GGML models are present (download if missing, convert from source if needed)
# ------------------------------
read -p "🔄 Do you want to download/convert models and download VAD? (y/n) " -n 1 -r
echo
if [[ $REPLY =~ ^[Yy]$ ]]; then
    MODELS="base.en medium.en large-v3 large-v3-turbo"

    echo "📦 Ensuring GGML models are present..."
    for model in $MODELS; do
        ggml="models/ggml-${model}.bin"

        if [ -s "$ggml" ]; then
            echo "   ✅ $ggml already present, skipping."
            continue
        fi

        # Try the pre-converted GGML download first (fast, no PyTorch needed)
        echo "   → $model: downloading pre-converted GGML..."
        if ./models/download-ggml-model.sh "$model"; then
            if [ -s "$ggml" ]; then
                echo "   ✅ $ggml downloaded."
                continue
            fi
        fi

        # Fallback: convert from the original PyTorch model via make
        echo "   → $model: download failed, converting from source (this will fetch the PyTorch model)..."
        make -j "$(sysctl -n hw.physicalcpu)" "$model"
    done

    echo "🍎 Generating Core ML models..."
    for model in $MODELS; do
        ggml="models/ggml-${model}.bin"
        [ -s "$ggml" ] || { echo "   ⏭️  $ggml missing, skipping Core ML for $model."; continue; }
        echo "   → $model (Core ML)"
        ./models/generate-coreml-model.sh "$model"
    done

    # ------------------------------
    # 3.1 Download VAD model
    # ------------------------------
    echo "📥 Downloading VAD model..."
    ./models/download-vad-model.sh
else
    echo "⏭️  Skipping model download/convert and VAD download."
fi

# ------------------------------
# 4. (Optional) Verify the built executables
# ------------------------------
echo "✅ All done! You can now run e.g. ./build/bin/whisper-cli -m models/ggml-base.en.bin -f sample.wav"
