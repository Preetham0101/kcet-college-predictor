# KCET College Predictor — district-first update

## Files
- `backend/app/main.py`: updated FastAPI prediction endpoint and district classification.
- `mobile/flutter_app/lib/main.dart`: updated Flutter results UI with district-group headings.

## Apply safely
1. Stop the running FastAPI and Flutter processes.
2. Back up your existing `backend/app/main.py` and `mobile/flutter_app/lib/main.dart`.
3. Copy the two files from this ZIP to the matching paths in your existing project.
4. Do not delete `backend/app/kcet_users.db`, `.venv`, `pubspec.yaml`, Android files, or other project files.
5. Restart FastAPI using your existing backend virtual environment.
6. Run `flutter analyze`, then rebuild using the current laptop Wi-Fi IP in `KCET_API_URL`.

## District-first behavior
- Selected district records appear first.
- Other districts with recognized address/locality aliases appear second.
- Records whose district cannot be safely inferred appear in a separate unverified statewide fallback group.
- Within each group, historical within-cutoff records appear before outside-cutoff records; the closest historical cutoff is shown first.
- This is a historical cutoff comparison, not a college-quality ranking or admission guarantee.

## Validation performed
The uploaded KEA 2026 PDF was parsed into 20,978 rows. For rank 35,000, category 3AG, branch filter `computer science`, selected district `Bengaluru`:
- 457 records matched the category/branch.
- 151 records were classified as Bengaluru Urban.
- 257 records were classified in other Karnataka districts.
- 49 records remained district-unverified and were separated from verified district groups.

Districts inferred from addresses are approximate alias-based classifications. Verify college district and current official KEA data before choice filling.
