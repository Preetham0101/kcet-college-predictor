# KCET College Predictor — Starter

Beginner-friendly starter project:
- `backend/`: FastAPI API, file parsing, historical cutoff comparison
- `web/`: Next.js website
- `mobile/README.md`: Flutter next steps

## Prerequisites
- Python 3.12+
- Node.js LTS and npm
- Flutter SDK later (not required to run the first prototype)

## 1. Start the backend (Windows PowerShell)

```powershell
cd backend
python -m venv .venv
.\.venv\Scripts\Activate.ps1
python -m pip install --upgrade pip
pip install -r requirements.txt
uvicorn app.main:app --reload
```

If PowerShell blocks activation, run this for the current terminal:
```powershell
Set-ExecutionPolicy -Scope Process -ExecutionPolicy Bypass
.\.venv\Scripts\Activate.ps1
```

Backend API: http://127.0.0.1:8000
Interactive API docs: http://127.0.0.1:8000/docs

## 2. Start the website (second terminal)

```powershell
cd web
npm install
npm run dev
```

Website: http://localhost:3000

## 3. Try the prototype
1. Open the website.
2. Enter rank and category (for example, rank `35000`, category `3AG`).
3. Upload a CSV, Excel, or text-based PDF cutoff file.
4. View the matching historical cutoff records.

A sample dataset is in `backend/sample_cutoffs.csv`.

## Expected file columns
The parser recognizes common variations of:
- college name
- course/branch
- category
- closing rank / cutoff rank
- optional college code, year, round, quota, location

The uploaded file must contain a category column and a closing-rank column. Include college and branch columns for useful results. PDF extraction depends on the PDF containing selectable text and detectable tables; scanned PDFs need OCR, which is not included yet.

## Important limitations
- This is a prototype, not an admission guarantee.
- “Historically within cutoff” means `student rank <= closing rank` for a matching category/course/round record. It does not mean admission is certain.
- Cutoffs are comparable only when category, quota, course, round, and other applicable seat conditions match.
- PDF table extraction varies by document. Inspect the parsed output and compare it against the official source before relying on it.
- Files are processed in memory for this prototype; they are not stored persistently. Add file-size limits, authentication, secure storage, rate limiting, and privacy controls before production.
- No real KCET cutoff values are included in the sample file; the sample rows are fictional test data.


## KEA wide-format PDF support
The API recognizes KEA UGCET-2026 engineering cutoff PDFs where reservation categories (such as `3AG`, `GM`) are columns. It converts each populated category value to a record and skips `--` values. The uploaded PDF identifies the seat type as Rest of Karnataka. Verify extracted branch names and cutoff values against the official PDF, especially when course names wrap across lines. This is a prototype parser and not an admission guarantee.


## Filters and Flutter app
Website: category dropdown, branch and district/location filters, search, and status filter. District filtering searches address/location text present in the file; it is not a verified district database. Flutter client source is in `mobile/flutter_app/lib/main.dart`; see its README to generate platform scaffolding and install dependencies.


## Professional results dashboard update
The website now uses a responsive two-column workspace, rank/category summary, clearer upload panel, historical cutoff metrics, searchable/sortable results table, and status filtering. It continues to call the existing FastAPI `/predict` endpoint. The district field still matches text in the uploaded data's location/address field; it is not a normalized official district directory. The Flutter starter is unchanged.

## Prediction accuracy and uploaded-data validation update
- Backend now returns the categories present in the uploaded file and a data-quality summary (years detected and missing college/branch/location counts).
- Category requests not present in the uploaded file return a clear validation error listing available categories.
- Location matching normalizes common city-name variants (e.g. Bangalore/Bengaluru, Mysore/Mysuru). It still searches the location/address text in the uploaded data; this is not a verified district directory.
- Results use three comparison labels: within historical cutoff (rank is equal to/better than closing rank), borderline (rank is up to 10% worse than closing rank), and outside historical cutoff. These labels are not admission probabilities or guarantees.
- KEA PDF parser whitespace normalization was corrected.

Validation performed in the build workspace: Python syntax check passed; sample CSV API request returned HTTP 200 and included data-quality metadata. A Next.js production build could not be run in this workspace because Node dependencies (`next`) were not installed here. Please test with the local project and an official KEA file before relying on results.


## Shortlist CSV export
After predicting, use **Export CSV** to download the currently visible results. The export respects the current text search and historical-status filter and includes college, code, branch, location, category, closing rank, year, round, quota, status, and rank difference. It exports only records returned to the browser by the API (currently capped at 500).

## District/location filter note
The backend normalizes common spelling variants (Bangalore/Bengaluru, Mysore/Mysuru, Belgaum/Belagavi, Gulbarga/Kalaburagi, Bijapur/Vijayapura, Hubli/Hubballi, Tumkur/Tumakuru) and searches the uploaded location/address text. It is not an official district registry, and matching depends on the location text present in the uploaded file.


## Save Colleges / My Shortlist
Students can use the **Save** button beside a college to add it to **My shortlist**. Saved entries persist in that browser using localStorage, without requiring login or sending saved choices to the backend. The shortlist can be searched, filtered by historical status, sorted, and exported as CSV. Because storage is browser-specific, saved colleges do not automatically sync between devices or browsers.

## Optional accounts and cloud-synced shortlist (MVP)
- Register or sign in on the website/mobile app with an email and password (minimum 8 characters).
- Saved college records sync through `GET /me/shortlist` and `PUT /me/shortlist`.
- Accounts and shortlists are stored in a local SQLite file at `backend/app/kcet_users.db` by default. Back up this file. For production, use managed persistent storage and HTTPS.
- Set a strong random `KCET_TOKEN_SECRET` environment variable before deployment. The fallback secret is for local development only and must not be used publicly.
- This MVP stores passwords using PBKDF2-HMAC-SHA256 and issues signed bearer tokens for 14 days. Add rate limiting, email verification, password reset, security monitoring, and a managed secret before public deployment.
- Browser local storage remains a local fallback. Cloud sync is optional and requires an account. Use the same deployed API URL for website and mobile to sync across devices.

### Flutter dependencies and setup
From `mobile/flutter_app`, run:
```bash
flutter pub add http file_picker shared_preferences
flutter run --dart-define=KCET_API_URL=http://10.0.2.2:8000
```
For a physical phone, replace `10.0.2.2` with your development computer's LAN IP. Both devices must be on the same trusted network. For deployed use, configure an HTTPS API URL. The included Flutter account UI supports register/login, saving colleges, a saved-college sheet, and cloud shortlist sync.
