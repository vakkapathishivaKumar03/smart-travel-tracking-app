#!/bin/bash
set -euo pipefail

FLUTTER_ROOT="$HOME/flutter"

if [ ! -d "$FLUTTER_ROOT" ]; then
  git clone --depth 1 https://github.com/flutter/flutter.git -b stable "$FLUTTER_ROOT"
fi

export PATH="$FLUTTER_ROOT/bin:$PATH"

flutter config --enable-web
cd smart_travel_app
flutter pub get
