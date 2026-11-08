KCET College Predictor - Search and Sorting UI update

This update is based on the latest Flutter main.dart shared in the project Library.

Changes:
- Search results by college name, college code, branch, location, district, or category.
- Sort by closing rank (ascending or descending) or college name (A-Z).
- Show total result count, historical-within-cutoff count, saved count, and filtered count.
- Search and sort are client-side only; FastAPI endpoints and request format are unchanged.

Apply safely:
1. Close the running Flutter app (press q in its flutter run terminal).
2. Back up your existing file:
   Copy lib\main.dart to lib\main_backup_before_search_sort.dart
3. Replace only:
   mobile\flutter_app\lib\main.dart
   with the main.dart in this ZIP.
4. Do not replace backend files, pubspec.yaml, Android files, database, or virtual environment.
5. From mobile\flutter_app run:
   flutter analyze
6. If analyze passes, run:
   flutter run -d 10BE181HUM001EZ --dart-define=KCET_API_URL=http://192.168.1.118:8000

Note: Keep the backend running. If your laptop's Wi-Fi IPv4 address changes, update the KCET_API_URL value accordingly.
