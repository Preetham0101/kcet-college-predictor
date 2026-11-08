# Flutter app — Phase 5

We'll add the Flutter app after the FastAPI backend is tested. It will call the same API endpoint:
`POST http://<your-computer-LAN-IP>:8000/predict`

For a physical Android phone, `127.0.0.1` points to the phone itself, not your computer. Use your computer's LAN IP while both devices are on the same trusted network, and configure CORS/network security appropriately. For the Android emulator, the host is commonly `10.0.2.2`.

Suggested first commands when ready:
```bash
flutter create mobile_app
cd mobile_app
flutter pub add http file_picker
```

Do not expose the development API directly to the public internet.
