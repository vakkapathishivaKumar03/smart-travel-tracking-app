#!/bin/bash
set -euo pipefail

FLUTTER_ROOT="$HOME/flutter"

if [ ! -d "$FLUTTER_ROOT" ]; then
  git clone --depth 1 https://github.com/flutter/flutter.git -b stable "$FLUTTER_ROOT"
fi

export PATH="$FLUTTER_ROOT/bin:$PATH"

cd smart_travel_app
flutter build web --release
