from __future__ import annotations
import io, re, os, sqlite3, hashlib, hmac, secrets, base64, json, time
from typing import Any
import pandas as pd
import pdfplumber
from pydantic import BaseModel
from fastapi import FastAPI, File, Form, HTTPException, UploadFile, Depends
from fastapi.security import HTTPAuthorizationCredentials, HTTPBearer
from fastapi.middleware.cors import CORSMiddleware

app = FastAPI(title="KCET College Predictor API", version="0.3.0")
app.add_middleware(
    CORSMiddleware,
    allow_origins=[
        "http://localhost:3000",
        "http://127.0.0.1:3000",
        "https://kcet-college-predictor-topaz.vercel.app",
    ],
    allow_credentials=True,
    allow_methods=["*"],
    allow_headers=["*"],
)


# Minimal account + cloud shortlist storage. Set KCET_TOKEN_SECRET to a long random secret in deployment.
DB_PATH = os.getenv("KCET_DB_PATH", os.path.join(os.path.dirname(__file__), "kcet_users.db"))
TOKEN_SECRET = os.getenv("KCET_TOKEN_SECRET", "CHANGE-ME-LOCAL-DEVELOPMENT-SECRET")
TOKEN_TTL = 60 * 60 * 24 * 14
bearer = HTTPBearer(auto_error=False)

class AuthBody(BaseModel):
    email: str
    password: str

class ShortlistBody(BaseModel):
    colleges: list[dict[str, Any]]

def db():
    con = sqlite3.connect(DB_PATH)
    con.row_factory = sqlite3.Row
    return con

def init_db():
    with db() as con:
        con.execute("CREATE TABLE IF NOT EXISTS users (id INTEGER PRIMARY KEY AUTOINCREMENT, email TEXT UNIQUE NOT NULL, password_hash TEXT NOT NULL, created_at INTEGER NOT NULL)")
        con.execute("CREATE TABLE IF NOT EXISTS shortlists (user_id INTEGER PRIMARY KEY, colleges_json TEXT NOT NULL DEFAULT '[]', updated_at INTEGER NOT NULL, FOREIGN KEY(user_id) REFERENCES users(id))")
init_db()

def password_hash(password: str, salt: bytes | None = None) -> str:
    salt = salt or secrets.token_bytes(16)
    digest = hashlib.pbkdf2_hmac("sha256", password.encode(), salt, 240_000)
    return base64.urlsafe_b64encode(salt).decode().rstrip("=") + "." + base64.urlsafe_b64encode(digest).decode().rstrip("=")

def verify_password(password: str, stored: str) -> bool:
    try:
        salt_part, digest_part = stored.split(".", 1)
        salt = base64.urlsafe_b64decode(salt_part + "=" * (-len(salt_part) % 4))
        return hmac.compare_digest(password_hash(password, salt).split(".",1)[1], digest_part)
    except Exception:
        return False

def b64json(data: dict) -> str:
    return base64.urlsafe_b64encode(json.dumps(data, separators=(",", ":")).encode()).decode().rstrip("=")

def create_token(user_id: int, email: str) -> str:
    head = b64json({"alg":"HS256","typ":"JWT"})
    body = b64json({"sub":user_id,"email":email,"exp":int(time.time())+TOKEN_TTL})
    msg = f"{head}.{body}"
    sig = base64.urlsafe_b64encode(hmac.new(TOKEN_SECRET.encode(), msg.encode(), hashlib.sha256).digest()).decode().rstrip("=")
    return f"{msg}.{sig}"

def token_user(credentials: HTTPAuthorizationCredentials | None = Depends(bearer)):
    if not credentials:
        raise HTTPException(401, "Sign in to sync your shortlist.")
    try:
        head, body, signature = credentials.credentials.split(".")
        msg = f"{head}.{body}"
        expected = base64.urlsafe_b64encode(hmac.new(TOKEN_SECRET.encode(), msg.encode(), hashlib.sha256).digest()).decode().rstrip("=")
        if not hmac.compare_digest(expected, signature): raise ValueError("signature")
        payload = json.loads(base64.urlsafe_b64decode(body + "=" * (-len(body) % 4)))
        if int(payload["exp"]) < int(time.time()): raise ValueError("expired")
        return {"id":int(payload["sub"]), "email":str(payload["email"])}
    except Exception:
        raise HTTPException(401, "Session expired or invalid. Please sign in again.")

@app.post("/auth/register")
def register(body: AuthBody):
    email = body.email.strip().lower()
    if not re.fullmatch(r"[^\s@]+@[^\s@]+\.[^\s@]+", email): raise HTTPException(422, "Enter a valid email address.")
    if len(body.password) < 8: raise HTTPException(422, "Password must contain at least 8 characters.")
    if len(body.password) > 256: raise HTTPException(422, "Password is too long.")
    try:
        with db() as con:
            cur = con.execute("INSERT INTO users(email,password_hash,created_at) VALUES(?,?,?)", (email,password_hash(body.password),int(time.time())))
            user_id = int(cur.lastrowid)
            con.execute("INSERT INTO shortlists(user_id,colleges_json,updated_at) VALUES(?,?,?)",(user_id,"[]",int(time.time())))
    except sqlite3.IntegrityError:
        raise HTTPException(409, "An account with this email already exists. Sign in instead.")
    return {"access_token":create_token(user_id,email),"token_type":"bearer","email":email}

@app.post("/auth/login")
def login(body: AuthBody):
    email=body.email.strip().lower()
    with db() as con: row=con.execute("SELECT id,email,password_hash FROM users WHERE email=?",(email,)).fetchone()
    if not row or not verify_password(body.password,row["password_hash"]): raise HTTPException(401,"Email or password is incorrect.")
    return {"access_token":create_token(int(row["id"]),row["email"]),"token_type":"bearer","email":row["email"]}

@app.get("/me")
def me(user=Depends(token_user)):
    return {"id":user["id"],"email":user["email"]}

@app.get("/me/shortlist")
def get_shortlist(user=Depends(token_user)):
    with db() as con: row=con.execute("SELECT colleges_json,updated_at FROM shortlists WHERE user_id=?",(user["id"],)).fetchone()
    colleges=json.loads(row["colleges_json"]) if row else []
    return {"colleges":colleges,"updated_at":row["updated_at"] if row else None}

@app.put("/me/shortlist")
def put_shortlist(body: ShortlistBody, user=Depends(token_user)):
    if len(body.colleges)>2000: raise HTTPException(413,"A shortlist can contain at most 2,000 records.")
    # Keep payload size bounded and only accept JSON-compatible objects.
    try: encoded=json.dumps(body.colleges, ensure_ascii=False, separators=(",", ":"))
    except (TypeError, ValueError): raise HTTPException(422,"Shortlist contains invalid data.")
    if len(encoded.encode("utf-8"))>2_000_000: raise HTTPException(413,"Shortlist is too large.")
    with db() as con:
        con.execute("INSERT INTO shortlists(user_id,colleges_json,updated_at) VALUES(?,?,?) ON CONFLICT(user_id) DO UPDATE SET colleges_json=excluded.colleges_json, updated_at=excluded.updated_at",(user["id"],encoded,int(time.time())))
    return {"saved":len(body.colleges),"updated_at":int(time.time())}

ALIASES = {
 "college":["college","college name","institute","institute name","college_name"],
 "branch":["branch","course","course name","discipline","program","programme"],
 "category":["category","cat","seat category","reservation category"],
 "cutoff":["cutoff","cutoff rank","closing rank","last rank","rank","closing_rank","cutoff_rank"],
 "college_code":["college code","institute code","code","college_code"],
 "year":["year","admission year","academic year"], "round":["round","round number","phase","counselling round","counseling round"],
 "quota":["quota","seat type","seat quota"], "location":["location","city","place"],
 "district":["district","college district","district name"],
}
KEA_CATEGORIES = ["1G","1K","1R","2AG","2AK","2AR","2BG","2BK","2BR","3AG","3AK","3AR","3BG","3BK","3BR","GM","GMK","GMP","GMR","NRI","OPN","OTH","S1G","S1K","S1R","S2G","S2K","S2R","S3G","S3K","S3R","S4G","S4K","S4R","STG","STK","STR"]
RANK_TOKEN = re.compile(r"^(?:--|\d+(?:\.\d+)?)$")

def clean_label(v: Any) -> str:
    return re.sub(r"[^a-z0-9]+"," ",str(v).strip().lower()).strip()


def normalize_location_query(value: str) -> str:
    """Normalize common Karnataka city spellings inside complete address strings."""
    text = clean_label(value)
    aliases = {
        "bangalore": "bengaluru", "bengaluru urban": "bengaluru",
        "mysore": "mysuru", "belgaum": "belagavi", "gulbarga": "kalaburagi",
        "bijapur": "vijayapura", "hubli": "hubballi", "tumkur": "tumakuru",
        "mangalore": "mangaluru", "bellary": "ballari",
    }
    for old, new in sorted(aliases.items(), key=lambda item: len(item[0]), reverse=True):
        text = re.sub(rf"\b{re.escape(old)}\b", new, text)
    return text


def location_matches(value: Any, query: str) -> bool:
    """Search uploaded address/location text; this is not official district verification."""
    normalized_query = normalize_location_query(query)
    if not normalized_query:
        return True
    return normalized_query in normalize_location_query(str(value or ""))


# District mapping is used only to group uploaded college records. If an address
# does not contain a sufficiently specific district/locality marker, it remains
# unverified and is shown in the statewide fallback rather than guessed.
DISTRICT_ALIASES = {
    "Bagalkot": ["bagalkot", "bagalkote"],
    "Ballari": ["ballari", "bellary"],
    "Belagavi": ["belagavi", "belgaum"],
    "Bengaluru Urban": ["bengaluru urban", "bangalore urban", "bengaluru city", "bangalore city"],
    "Bengaluru Rural": ["bengaluru rural", "bangalore rural", "devanahalli", "doddaballapura", "nelamangala"],
    "Bidar": ["bidar"],
    "Chamarajanagar": ["chamarajanagar", "chamarajnagar"],
    "Chikkaballapura": ["chikkaballapura", "chikballapur", "chikkaballapur"],
    "Chikkamagaluru": ["chikkamagaluru", "chikmagalur"],
    "Chitradurga": ["chitradurga"],
    "Dakshina Kannada": ["dakshina kannada", "south kannada", "mangaluru", "mangalore", "puttur", "bantwal", "sullia"],
    "Davanagere": ["davanagere", "davangere"],
    "Dharwad": ["dharwad", "hubballi", "hubli"],
    "Gadag": ["gadag"],
    "Hassan": ["hassan"],
    "Haveri": ["haveri"],
    "Kalaburagi": ["kalaburagi", "gulbarga"],
    "Kodagu": ["kodagu", "coorg", "madikeri"],
    "Kolar": ["kolar"],
    "Koppal": ["koppal"],
    "Mandya": ["mandya"],
    "Mysuru": ["mysuru", "mysore"],
    "Raichur": ["raichur"],
    "Ramanagara": ["ramanagara", "ramanagaram", "channapatana", "channapatna", "kanakapura", "magadi", "harohalli"],
    "Shivamogga": ["shivamogga", "shimoga"],
    "Tumakuru": ["tumakuru", "tumkur"],
    "Udupi": ["udupi", "kundapura", "karkala"],
    "Uttara Kannada": ["uttara kannada", "north canara", "karwar", "sirsi", "kumta", "honnavar"],
    "Vijayapura": ["vijayapura", "bijapur"],
    "Yadgir": ["yadgir"],
    "Vijayanagara": ["vijayanagara", "hosapete", "hospet"],
}

def canonical_district(value: Any) -> str | None:
    """Resolve a user-entered district name/known alias to a canonical district."""
    text = clean_label(value)
    if not text:
        return None
    if text in {"bengaluru", "bangalore"}:
        return "Bengaluru Urban"
    if text in {"ramanagaram", "channapatana", "channapatna"}:
        return "Ramanagara"
    for district, aliases in DISTRICT_ALIASES.items():
        if text == clean_label(district) or text in {clean_label(a) for a in aliases}:
            return district
    return None

def infer_district_from_address(value: Any) -> str | None:
    """Infer a district only from a known district or locality alias in the address."""
    text = clean_label(value)
    if not text:
        return None

    # Match longer/specific aliases first. This makes Channapatana -> Ramanagara
    # win over a broad Bangalore South/Bangalore mention in the same address.
    candidates = []
    for district, aliases in DISTRICT_ALIASES.items():
        for alias in aliases:
            normalized = clean_label(alias)
            if normalized and re.search(rf"(?<![a-z0-9]){re.escape(normalized)}(?![a-z0-9])", text):
                candidates.append((len(normalized), district))
    if candidates:
        candidates.sort(key=lambda item: item[0], reverse=True)
        longest = candidates[0][0]
        best = {district for length, district in candidates if length == longest}
        return next(iter(best)) if len(best) == 1 else None

    # A bare Bengaluru/Bangalore address is accepted only when it does not also
    # mention a more specific non-Bengaluru district/locality alias.
    if re.search(r"(?<![a-z0-9])(bengaluru|bangalore)(?![a-z0-9])", text):
        return "Bengaluru Urban"
    return None

def district_for_record(row: pd.Series) -> tuple[str | None, str]:
    explicit = str(row.get("district", "") or "").strip()
    if explicit:
        resolved = canonical_district(explicit)
        if resolved:
            return resolved, "explicit"
    inferred = infer_district_from_address(row.get("location", ""))
    return (inferred, "address_inferred") if inferred else (None, "unverified")

def normalize_columns(df: pd.DataFrame) -> pd.DataFrame:
    if df.empty: raise ValueError("The file does not contain any data rows.")
    mapping={}
    aliases={k:{clean_label(x) for x in vals} for k,vals in ALIASES.items()}
    for c in df.columns:
        for target, vals in aliases.items():
            if clean_label(c) in vals: mapping[c]=target; break
    df=df.rename(columns=mapping)
    df=df.loc[:,~df.columns.duplicated()].copy()
    missing=[c for c in ("category","cutoff") if c not in df.columns]
    if missing: raise ValueError("Could not identify required column(s): "+", ".join(missing)+". Include Category and Closing Rank headers.")
    for c in ("college","branch","college_code","year","round","quota","location","district"):
        if c not in df.columns: df[c]=""
    df["category"]=df["category"].astype(str).str.strip().str.upper()
    df["cutoff"]=pd.to_numeric(df["cutoff"].astype(str).str.replace(",","",regex=False).str.replace(r"[^0-9.]","",regex=True),errors="coerce")
    df=df.dropna(subset=["cutoff"])
    df=df[df["category"].ne("") & df["category"].ne("NAN")]
    if df.empty: raise ValueError("No usable rows found. Check category and closing-rank values.")
    for c in ("college","branch","college_code","year","round","quota","location","district"): df[c]=df[c].fillna("").astype(str).str.strip()
    return df

def parse_kea_pdf(content: bytes) -> pd.DataFrame:
    """Parse KEA wide-format cutoff PDFs into one row per college/branch/category."""
    records: list[dict[str, Any]] = []
    college_name = college_code = seat_type = college_address = ""
    categories: list[str] | None = None
    pending: dict[str, Any] | None = None
    year = "2026"

    def flush() -> None:
        nonlocal pending
        if not pending:
            return
        branch = re.sub(r"\s+", " ", " ".join(pending["branch_parts"])).strip()
        if branch:
            for category_name, raw_cutoff in zip(pending["categories"], pending["values"]):
                if raw_cutoff == "--":
                    continue
                try:
                    cutoff = float(raw_cutoff.replace(",", ""))
                except ValueError:
                    continue
                records.append({
                    "college": pending["college"],
                    "college_code": pending["college_code"],
                    "branch": branch,
                    "category": category_name,
                    "cutoff": cutoff,
                    "year": pending["year"],
                    "round": "",
                    "quota": pending["seat_type"],
                    "location": pending["college_address"],
                    "district": infer_district_from_address(pending["college_address"]) or "",
                })
        pending = None

    footer_prefixes = (
        "sc sub category", "generated on:", "page ", "karnataka examinations authority",
        "non-interactive", "ugcet-", "seat type:", "course name",
    )

    with pdfplumber.open(io.BytesIO(content)) as pdf:
        for page in pdf.pages:
            lines = [re.sub(r"\s+", " ", line).strip()
                     for line in (page.extract_text() or "").splitlines()]
            for line in lines:
                if not line:
                    continue

                college_match = re.match(r"College:\s*([A-Z]\d{3})\s*(.*)", line, flags=re.I)
                if college_match:
                    flush()
                    college_code = college_match.group(1).upper()
                    raw_header = re.sub(r"\s+", " ", college_match.group(2)).strip(" ,;-")
                    if "," in raw_header:
                        college_name = raw_header.split(",", 1)[0].strip()
                    else:
                        college_name = raw_header
                    # Keep the complete printed header searchable. The KEA PDF does
                    # not provide a reliably separate district column.
                    college_address = raw_header
                    categories = None
                    continue

                if line.lower().startswith("seat type:"):
                    seat_type = line.split(":", 1)[1].strip()
                    continue
                if "UGCET-2026" in line.upper():
                    year = "2026"

                tokens = line.split()
                is_category_header = (
                    "Course" in tokens and "Name" in tokens
                    and sum(token in KEA_CATEGORIES for token in tokens) >= 25
                )
                if is_category_header:
                    flush()
                    categories = [token for token in tokens if token in KEA_CATEGORIES]
                    continue

                if categories and len(tokens) >= len(categories):
                    tail = tokens[-len(categories):]
                    is_cutoff_row = (
                        all(RANK_TOKEN.fullmatch(token.replace(",", "")) for token in tail)
                        and any(token != "--" for token in tail)
                    )
                    if is_cutoff_row:
                        flush()
                        prefix = " ".join(tokens[:-len(categories)]).strip()
                        pending = {
                            "college": college_name or "College name not detected",
                            "college_code": college_code,
                            "branch_parts": [prefix] if prefix else [],
                            "categories": categories,
                            "values": tail,
                            "seat_type": seat_type,
                            "college_address": college_address,
                            "year": year,
                        }
                        continue

                # Course names in the KEA PDF wrap onto one or more following lines.
                if pending and not line.lower().startswith(footer_prefixes):
                    if not re.search(r"\bpage\s+\d+\s+of\s+\d+\b", line, re.I):
                        if not line.startswith("College:") and not is_category_header:
                            pending["branch_parts"].append(line)
            flush()

    if not records:
        raise ValueError(
            "No KEA cutoff rows were extracted. Check that this is a text-based "
            "KEA UGCET engineering cutoff PDF."
        )

    result = pd.DataFrame(records)
    result["cutoff"] = pd.to_numeric(result["cutoff"], errors="coerce")
    result = result.dropna(subset=["cutoff"])
    result["category"] = result["category"].astype(str).str.strip().str.upper()
    result["branch"] = result["branch"].astype(str).str.replace(r"\s+", " ", regex=True).str.strip()
    return result

def read_uploaded_file(filename: str, content: bytes) -> pd.DataFrame:
    ext=filename.lower().rsplit(".",1)[-1] if "." in filename else ""
    try:
        if ext=="csv":
            try: return pd.read_csv(io.BytesIO(content))
            except UnicodeDecodeError: return pd.read_csv(io.BytesIO(content),encoding="latin-1")
        if ext in ("xlsx","xls"): return pd.read_excel(io.BytesIO(content))
        if ext=="pdf": return parse_kea_pdf(content)
    except ValueError: raise
    except Exception as exc: raise ValueError(f"Could not read this file: {exc}") from exc
    raise ValueError("Unsupported file type. Upload CSV, Excel, or PDF.")

@app.get("/health")
def health(): return {"status":"ok","service":"kcet-college-predictor"}

@app.post("/predict")
async def predict(rank:int=Form(...,ge=1), category:str=Form(...,min_length=1,max_length=30),
                  branch:str=Form(default="",max_length=100), location:str=Form(default="",max_length=100),
                  round_name:str=Form(default="",max_length=50), file:UploadFile=File(...)):
    if not file.filename: raise HTTPException(400,"Please choose a cutoff file.")
    if not file.filename.lower().endswith((".csv",".xlsx",".xls",".pdf")): raise HTTPException(400,"Upload CSV, Excel, or PDF.")
    content=await file.read()
    if not content: raise HTTPException(400,"The uploaded file is empty.")
    if len(content)>15*1024*1024: raise HTTPException(413,"File too large. Maximum size is 15 MB.")
    try:
        raw=read_uploaded_file(file.filename,content)
        df=raw if file.filename.lower().endswith(".pdf") else normalize_columns(raw)
    except ValueError as exc: raise HTTPException(422,str(exc)) from exc
    requested=category.strip().upper()
    available_categories=sorted({str(v).strip().upper() for v in df["category"].dropna() if str(v).strip()})
    if requested not in available_categories:
        raise HTTPException(422, f"Category '{requested}' was not found in this file. Available categories: {', '.join(available_categories[:30]) or 'none'}")
    filtered=df[df["category"].astype(str).str.upper()==requested].copy()
    if branch.strip():
        filtered=filtered[filtered["branch"].str.contains(re.escape(branch.strip()),case=False,na=False)]
    if round_name.strip():
        filtered=filtered[filtered["round"].str.contains(re.escape(round_name.strip()),case=False,na=False)]

    selected_district = canonical_district(location) if location.strip() else None
    if location.strip() and selected_district is None:
        raise HTTPException(
            422,
            "Enter a Karnataka district name, for example Bengaluru Urban, Bengaluru Rural, Mysuru, Mandya or Ramanagara."
        )

    if filtered.empty:
        return {"rank":rank,"category":requested,"uploaded_rows":int(len(df)),"matched_rows":0,"results":[],
                "available_categories":available_categories,
                "selected_district":selected_district,
                "district_match_count":0,"statewide_fallback_count":0,
                "data_quality":{"years":sorted({str(v) for v in df["year"] if str(v).strip()}),
                    "rows_missing_college":int(df["college"].eq("").sum()),"rows_missing_branch":int(df["branch"].eq("").sum()),
                    "rows_missing_location":int(df["location"].eq("").sum()),"source_type":file.filename.rsplit(".",1)[-1].lower()},
                "message":"No rows matched the category, branch and round filters.",
                "notice":"Historical cutoff comparisons are not admission guarantees."}

    district_values = filtered.apply(district_for_record, axis=1)
    filtered["district"] = [item[0] or "" for item in district_values]
    filtered["district_source"] = [item[1] for item in district_values]

    filtered["status"] = filtered["cutoff"].apply(
        lambda cutoff: "Historically within cutoff" if rank <= float(cutoff)
        else "Historically outside cutoff"
    )
    filtered["rank_difference"] = (filtered["cutoff"] - rank).round().astype(int)
    filtered["_district_group"] = (
        0 if selected_district is None else
        filtered.apply(
            lambda row: 0 if row["district"] == selected_district
            else (2 if not row["district"] else 1),
            axis=1,
        )
    )
    filtered["_status_group"] = filtered["status"].map({
        "Historically within cutoff": 0,
        "Historically outside cutoff": 1,
    })
    # Within each district group, show historical within-cutoff rows first,
    # then the closest cutoff comparisons. This ranks cutoff fit, not college quality.
    filtered["_rank_gap"] = filtered["rank_difference"].abs()
    filtered = filtered.sort_values(
        ["_district_group", "_status_group", "_rank_gap", "cutoff"],
        ascending=[True, True, True, True],
        kind="stable",
    )
    filtered["match_group"] = filtered["_district_group"].map({
        0: "Selected district" if selected_district else "Karnataka",
        1: "Other Karnataka districts",
        2: "Karnataka fallback — district unverified",
    })

    results=[]
    for _,r in filtered.head(500).iterrows():
        cutoff=float(r["cutoff"])
        results.append({"college":r["college"] or "College name not provided","college_code":r["college_code"] or None,
            "branch":r["branch"] or "Branch not provided","category":r["category"],
            "cutoff_rank":int(cutoff) if cutoff.is_integer() else cutoff,"year":r["year"] or None,
            "round":r["round"] or None,"quota":r["quota"] or None,"location":r["location"] or None,
            "status":r["status"],"rank_difference":int(r["rank_difference"]),
            "district":r["district"] or None,"district_source":r["district_source"],
            "match_group":r["match_group"],
            "rank_comparison":"Your rank is better than or equal to the historical closing rank." if r["status"] == "Historically within cutoff" else "Your rank is worse than the historical closing rank."})
    district_match_count = int((filtered["district"] == selected_district).sum()) if selected_district else int(len(filtered))
    statewide_fallback_count = int(len(filtered) - district_match_count) if selected_district else 0
    unverified_district_count = int(filtered["district"].eq("").sum())
    data_quality={"years":sorted({str(v) for v in df["year"] if str(v).strip()}),
        "rows_missing_college":int(df["college"].eq("").sum()),"rows_missing_branch":int(df["branch"].eq("").sum()),
        "rows_missing_location":int(df["location"].eq("").sum()),"source_type":file.filename.rsplit(".",1)[-1].lower(),
        "categories_found":len(available_categories),"filtered_rows_before_rank_comparison":int(len(filtered)),
        "rows_with_verified_or_inferred_district":int(filtered["district"].ne("").sum()),
        "rows_with_unverified_district":int(filtered["district"].eq("").sum()),
        "district_matching":"Explicit district column or conservative known locality/address aliases; unmatched rows are not guessed."}
    district_notice = (
        f"{district_match_count} records were classified in {selected_district}; "
        f"{statewide_fallback_count} additional records are shown as statewide fallback."
        if selected_district else
        "No district was selected, so results are ranked across Karnataka."
    )
    return {"rank":rank,"category":requested,"selected_district":selected_district,
        "district_match_count":district_match_count,"statewide_fallback_count":statewide_fallback_count,
        "unverified_district_count":unverified_district_count,
        "uploaded_rows":int(len(df)),"matched_rows":int(len(filtered)),
        "available_categories":available_categories,"data_quality":data_quality,
        "results":results,"message":"Results are based only on uploaded historical records.",
        "district_notice":district_notice,
        "notice":"Within cutoff means your rank is numerically equal to or better than the uploaded historical closing rank. Outside cutoff means it is worse. Results are ordered by selected district first, then statewide fallback, and by closest historical cutoff within each group. This is not a college-quality ranking, admission probability or guarantee. Verify the exact year, round, category, seat type and official KEA data before choice filling."}
