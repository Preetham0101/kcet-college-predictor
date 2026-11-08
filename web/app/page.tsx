"use client";
import { FormEvent, useEffect, useMemo, useState } from "react";

type Result = {
  college: string; college_code: string | null; branch: string; category: string;
  cutoff_rank: number; year: string | null; round: string | null; quota: string | null;
  location: string | null; status: string; rank_difference: number;
};
type Prediction = {
  rank: number; category: string; uploaded_rows: number; matched_rows: number;
  results: Result[]; message: string; notice: string;
  available_categories?: string[];
  data_quality?: { years: string[]; rows_missing_college: number; rows_missing_branch: number; rows_missing_location: number; source_type: string; categories_found: number; filtered_rows_before_rank_comparison?: number };
};
const API_URL = process.env.NEXT_PUBLIC_API_URL || "http://127.0.0.1:8000";
const CATEGORIES = ["1G","1K","1R","2AG","2AK","2AR","2BG","2BK","2BR","3AG","3AK","3AR","3BG","3BK","3BR","GM","GMK","GMP","GMR","NRI","OPN","OTH","S1G","S1K","S1R","S2G","S2K","S2R","S3G","S3K","S3R","S4G","S4K","S4R","STG","STK","STR"];

export default function Home() {
  const [rank,setRank] = useState("35000");
  const [category,setCategory] = useState("3AG");
  const [branch,setBranch] = useState("");
  const [district,setDistrict] = useState("");
  const [roundName,setRoundName] = useState("");
  const [file,setFile] = useState<File|null>(null);
  const [loading,setLoading] = useState(false);
  const [error,setError] = useState("");
  const [prediction,setPrediction] = useState<Prediction|null>(null);
  const [search,setSearch] = useState("");
  const [status,setStatus] = useState("all");
  const [sortBy,setSortBy] = useState("recommended");
  const [saved,setSaved] = useState<Result[]>([]);
  const [showSavedOnly,setShowSavedOnly] = useState(false);
  const [token,setToken] = useState("");
  const [accountEmail,setAccountEmail] = useState("");
  const [authEmail,setAuthEmail] = useState("");
  const [authPassword,setAuthPassword] = useState("");
  const [authMode,setAuthMode] = useState<"login"|"register">("login");
  const [authMessage,setAuthMessage] = useState("");
  const [authBusy,setAuthBusy] = useState(false);
  const [cloudLoaded,setCloudLoaded] = useState(false);

  useEffect(() => {
    try {
      const raw = window.localStorage.getItem("kcet-predictor-saved-colleges-v1");
      if (raw) setSaved(JSON.parse(raw) as Result[]);
      const savedToken = window.localStorage.getItem("kcet-cloud-token-v1") || "";
      const savedEmail = window.localStorage.getItem("kcet-cloud-email-v1") || "";
      if (savedToken) { setToken(savedToken); setAccountEmail(savedEmail); }
      else setCloudLoaded(true);
    } catch { setCloudLoaded(true); }
  }, []);

  useEffect(() => {
    if (!token) return;
    let active = true;
    (async () => {
      try {
        const r = await fetch(`${API_URL}/me/shortlist`, { headers: { Authorization: `Bearer ${token}` } });
        if (!r.ok) throw new Error("Session expired");
        const data = await r.json();
        if (active && Array.isArray(data.colleges)) setSaved(data.colleges as Result[]);
      } catch {
        if (active) { window.localStorage.removeItem("kcet-cloud-token-v1"); window.localStorage.removeItem("kcet-cloud-email-v1"); setToken(""); setAccountEmail(""); setAuthMessage("Could not sync cloud shortlist. Please sign in again."); }
      } finally { if (active) setCloudLoaded(true); }
    })();
    return () => { active = false; };
  }, [token]);

  useEffect(() => {
    try { window.localStorage.setItem("kcet-predictor-saved-colleges-v1", JSON.stringify(saved)); }
    catch { /* Saving remains available for this session if storage is blocked. */ }
  }, [saved]);

  useEffect(() => {
    if (!token || !cloudLoaded) return;
    const timer = window.setTimeout(async () => {
      try {
        const r = await fetch(`${API_URL}/me/shortlist`, { method: "PUT", headers: { "Content-Type": "application/json", Authorization: `Bearer ${token}` }, body: JSON.stringify({ colleges: saved }) });
        if (!r.ok) throw new Error("Cloud sync failed");
        setAuthMessage("Shortlist synced to your account.");
      } catch { setAuthMessage("Cloud sync failed. Your local shortlist is still available on this browser."); }
    }, 500);
    return () => window.clearTimeout(timer);
  }, [saved, token, cloudLoaded]);

  async function submitAuth(e: FormEvent<HTMLFormElement>) {
    e.preventDefault(); setAuthBusy(true); setAuthMessage("");
    try {
      const r = await fetch(`${API_URL}/auth/${authMode === "register" ? "register" : "login"}`, { method: "POST", headers: { "Content-Type": "application/json" }, body: JSON.stringify({ email: authEmail, password: authPassword }) });
      const data = await r.json();
      if (!r.ok) throw new Error(data.detail || "Account request failed.");
      window.localStorage.setItem("kcet-cloud-token-v1", data.access_token);
      window.localStorage.setItem("kcet-cloud-email-v1", data.email);
      setAccountEmail(data.email); setToken(data.access_token); setAuthPassword(""); setAuthMessage(authMode === "register" ? "Account created. Loading your cloud shortlist…" : "Signed in. Loading your cloud shortlist…"); setCloudLoaded(false);
    } catch (err) { setAuthMessage(err instanceof Error ? err.message : "Could not sign in."); }
    finally { setAuthBusy(false); }
  }

  function signOut() {
    window.localStorage.removeItem("kcet-cloud-token-v1"); window.localStorage.removeItem("kcet-cloud-email-v1");
    setToken(""); setAccountEmail(""); setCloudLoaded(true); setAuthMessage("Signed out. Saved colleges remain on this browser.");
  }

  function resultKey(x: Result) {
    return [x.college_code || x.college, x.branch, x.category, x.cutoff_rank, x.year || "", x.round || "", x.quota || ""].join("|").toLowerCase();
  }

  function isSaved(x: Result) { return saved.some(item => resultKey(item) === resultKey(x)); }

  function toggleSaved(x: Result) {
    setSaved(current => current.some(item => resultKey(item) === resultKey(x))
      ? current.filter(item => resultKey(item) !== resultKey(x))
      : [...current, x]);
  }

  async function submit(e:FormEvent<HTMLFormElement>) {
    e.preventDefault(); setError(""); setPrediction(null);
    if (!file) { setError("Please upload a previous-year cutoff file."); return; }
    if (!Number.isInteger(Number(rank)) || Number(rank)<1) { setError("Enter a valid positive KCET rank."); return; }
    const data = new FormData();
    data.append("rank",rank); data.append("category",category); data.append("branch",branch);
    data.append("location",district); data.append("round_name",roundName); data.append("file",file);
    setLoading(true);
    try {
      const r = await fetch(`${API_URL}/predict`,{method:"POST",body:data});
      const j = await r.json();
      if (!r.ok) throw new Error(j.detail || "Prediction failed. Check that the backend is running.");
      setPrediction(j as Prediction); setSearch(""); setStatus("all"); setSortBy("recommended");
    } catch(err) { setError(err instanceof Error ? err.message : "Something went wrong."); }
    finally { setLoading(false); }
  }

  const shown = useMemo(() => {
    if (!prediction) return [];
    const q = search.trim().toLowerCase();
    const source = showSavedOnly ? saved : prediction.results;
    const filtered = source.filter(x => {
      const text = [x.college,x.college_code||"",x.branch,x.location||"",x.category,x.quota||""].join(" ").toLowerCase();
      const matchesSearch = !q || text.includes(q);
      const matchesStatus = status==="all" ||
        (status==="within" && x.status==="Historically within cutoff") ||
        (status==="borderline" && x.status==="Borderline to historical cutoff") ||
        (status==="outside" && x.status==="Historically outside cutoff");
      return matchesSearch && matchesStatus;
    });
    return filtered.sort((a,b) => {
      if (sortBy==="cutoff-asc") return a.cutoff_rank-b.cutoff_rank;
      if (sortBy==="cutoff-desc") return b.cutoff_rank-a.cutoff_rank;
      if (sortBy==="college") return a.college.localeCompare(b.college);
      const order: Record<string, number> = {"Historically within cutoff":0,"Borderline to historical cutoff":1,"Historically outside cutoff":2};
      const aWithin = order[a.status] ?? 3;
      const bWithin = order[b.status] ?? 3;
      return aWithin-bWithin || b.rank_difference-a.rank_difference;
    });
  },[prediction,search,status,sortBy,saved,showSavedOnly]);

  function exportCSV() {
    if (!shown.length) return;
    const columns: { key: keyof Result; label: string }[] = [
      { key: "college", label: "College" },
      { key: "college_code", label: "College Code" },
      { key: "branch", label: "Branch" },
      { key: "location", label: "District / Location" },
      { key: "category", label: "Category" },
      { key: "cutoff_rank", label: "Historical Closing Rank" },
      { key: "year", label: "Year" },
      { key: "round", label: "Counselling Round" },
      { key: "quota", label: "Seat Type / Quota" },
      { key: "status", label: "Historical Status" },
      { key: "rank_difference", label: "Closing Rank Minus Your Rank" },
    ];
    const cell = (value: unknown) => `"${String(value ?? "").replace(/"/g, '""')}"`;
    const csv = [
      columns.map(c => cell(c.label)).join(","),
      ...shown.map(row => columns.map(c => cell(row[c.key])).join(",")),
    ].join("\r\n");
    const blob = new Blob(["\uFEFF", csv], { type: "text/csv;charset=utf-8;" });
    const url = URL.createObjectURL(blob);
    const link = document.createElement("a");
    link.href = url;
    link.download = `kcet-${showSavedOnly ? "saved-colleges" : "college-shortlist"}-rank-${rank}.csv`;
    document.body.appendChild(link);
    link.click();
    link.remove();
    URL.revokeObjectURL(url);
  }

  const withinCount = prediction?.results.filter(x=>x.status==="Historically within cutoff").length ?? 0;
  const borderlineCount = prediction?.results.filter(x=>x.status==="Borderline to historical cutoff").length ?? 0;
  const outsideCount = prediction?.results.filter(x=>x.status==="Historically outside cutoff").length ?? 0;

  return (
    <main className="app-shell">
      <nav className="topbar">
        <div className="brand"><div className="brand-mark">K</div><div><strong>KCET Predictor</strong><span>College discovery workspace</span></div></div>
        <div className="topbar-right"><span className="live-dot"/> Historical cutoff analysis <span className="topbar-divider"/> KEA PDF · CSV · Excel</div>
      </nav>
      <section className="account-panel">
        {token ? <div className="account-signed"><div><strong>Cloud shortlist enabled</strong><span>{accountEmail} · {authMessage || "Saved colleges sync to your account"}</span></div><button type="button" onClick={signOut}>Sign out</button></div> : <form className="account-form" onSubmit={submitAuth}><div className="account-title"><strong>{authMode === "login" ? "Sync your shortlist across devices" : "Create an account to sync colleges"}</strong><span>Optional · Password must be at least 8 characters</span></div><input aria-label="Email" type="email" required value={authEmail} onChange={e=>setAuthEmail(e.target.value)} placeholder="Email address"/><input aria-label="Password" type="password" required minLength={8} value={authPassword} onChange={e=>setAuthPassword(e.target.value)} placeholder="Password (8+ characters)"/><button type="submit" disabled={authBusy}>{authBusy ? "Please wait…" : authMode === "login" ? "Sign in" : "Create account"}</button><button type="button" className="account-switch" onClick={()=>{setAuthMode(authMode === "login" ? "register" : "login");setAuthMessage("")}}>{authMode === "login" ? "New here? Create account" : "Already have an account? Sign in"}</button>{authMessage && <span className="account-message">{authMessage}</span>}</form>}
      </section>

      <section className="hero">
        <div className="hero-copy">
          <div className="eyebrow"><span className="eyebrow-line"/> KCET ADMISSION PLANNER</div>
          <h1>Find your next<br/><span>engineering college.</span></h1>
          <p>Compare your KCET rank with previous-year closing ranks. Explore options by category, branch and district—all in one place.</p>
          <div className="hero-note"><span className="note-icon">i</span> Predictions use the cutoff file you upload. Historical matches are not admission guarantees.</div>
        </div>
        <div className="hero-stat"><div className="stat-icon">↗</div><div className="stat-label">YOUR STARTING POINT</div><div className="stat-number">{Number(rank||0).toLocaleString("en-IN")}</div><div className="stat-caption">KCET rank entered</div><div className="stat-rule"/><div className="stat-bottom"><span>Category</span><strong>{category}</strong></div></div>
      </section>

      <div className="workspace">
        <aside className="filter-panel">
          <div className="panel-heading"><div><span className="section-kicker">PERSONALIZE</span><h2>Your preferences</h2></div><span className="filter-icon">☷</span></div>
          <form onSubmit={submit}>
            <div className="field"><label htmlFor="rank">KCET rank <span className="required">*</span></label><input id="rank" type="number" min="1" required value={rank} onChange={e=>setRank(e.target.value)} placeholder="e.g. 35000"/></div>
            <div className="field"><label htmlFor="category">Reservation category <span className="required">*</span></label><select id="category" value={category} onChange={e=>setCategory(e.target.value)}>{CATEGORIES.map(c=><option key={c} value={c}>{c}</option>)}</select><small>Use the category code from the official cutoff data.</small></div>
            <div className="field"><label htmlFor="branch">Preferred branch</label><input id="branch" value={branch} onChange={e=>setBranch(e.target.value)} placeholder="e.g. Computer Science"/><small>Partial names work, e.g. “Mechanical”.</small></div>
            <div className="field"><label htmlFor="district">District / location</label><input id="district" value={district} onChange={e=>setDistrict(e.target.value)} placeholder="e.g. Bengaluru, Mysuru"/><small>Matches location/address text found in your file.</small></div>
            <div className="field"><label htmlFor="round">Counselling round</label><input id="round" value={roundName} onChange={e=>setRoundName(e.target.value)} placeholder="Optional · e.g. Round 1"/></div>
            <div className="upload-box"><div className="upload-symbol">↑</div><div className="upload-copy"><strong>{file ? file.name : "Upload cutoff data"}</strong><span>{file ? `${(file.size/1024/1024).toFixed(2)} MB · Selected` : "PDF, CSV or Excel · Up to 15 MB"}</span></div><label className="choose-file" htmlFor="file">Browse</label><input className="file-input" id="file" type="file" required accept=".csv,.xlsx,.xls,.pdf" onChange={e=>setFile(e.target.files?.[0]||null)}/></div>
            <button className="primary-button" type="submit" disabled={loading}>{loading ? <><span className="spinner"/> Analyzing cutoff data…</> : <>Find matching colleges <span>→</span></>}</button>
            {error && <div className="error" role="alert">{error}</div>}
          </form>
          <div className="privacy-note"><span>✓</span> Your uploaded file is processed for this prediction request.</div>
        </aside>

        <section className="results-panel" aria-live="polite">
          {!prediction ? (
            <div className="empty-state">
              <div className="empty-illustration"><div className="illus-sheet"><span/><span/><span/></div><div className="illus-cap">◆</div><div className="illus-search">⌕</div></div>
              <span className="section-kicker">YOUR RESULTS</span><h2>Your college shortlist starts here.</h2>
              <p>Enter your rank, choose your category and upload a historical cutoff file to discover colleges worth exploring.</p>
              <div className="empty-steps"><div><b>01</b><span>Enter your details</span></div><div><b>02</b><span>Upload cutoff data</span></div><div><b>03</b><span>Explore matches</span></div></div>
            </div>
          ) : (
            <>
              <div className="results-title-row"><div><span className="section-kicker">YOUR RESULTS</span><h2>Historical cutoff comparison</h2><p>Based on the data you uploaded for rank {prediction.rank.toLocaleString("en-IN")}.</p></div><span className="result-count">{prediction.matched_rows.toLocaleString("en-IN")} <small>records</small></span></div>
              <div className="metric-grid">
                <div className="metric-card"><span className="metric-icon blue">▤</span><div><small>Records analyzed</small><strong>{prediction.uploaded_rows.toLocaleString("en-IN")}</strong></div></div>
                <div className="metric-card"><span className="metric-icon green">✓</span><div><small>Within historical cutoff</small><strong>{withinCount.toLocaleString("en-IN")}</strong></div></div>
                <div className="metric-card"><span className="metric-icon amber">≈</span><div><small>Borderline comparisons</small><strong>{borderlineCount.toLocaleString("en-IN")}</strong></div></div>
                <div className="metric-card"><span className="metric-icon amber">↗</span><div><small>Beyond historical cutoff</small><strong>{outsideCount.toLocaleString("en-IN")}</strong></div></div>
              </div>
              {prediction.data_quality && <div className="quality-panel"><div className="quality-heading"><strong>Uploaded data check</strong><span>{prediction.data_quality.source_type.toUpperCase()} · {prediction.data_quality.categories_found} categories detected</span></div><div className="quality-items"><span>Years: <b>{prediction.data_quality.years.join(", ") || "Not detected"}</b></span><span>Missing college names: <b>{prediction.data_quality.rows_missing_college}</b></span><span>Missing branches: <b>{prediction.data_quality.rows_missing_branch}</b></span><span>Missing locations: <b>{prediction.data_quality.rows_missing_location}</b></span></div></div>}
              <div className="notice"><strong>Keep in mind:</strong> {prediction.notice || "Historical closing ranks are a reference only. They do not guarantee admission."}</div>
              <div className="shortlist-tabs" role="group" aria-label="College list view"><button type="button" className={!showSavedOnly ? "active" : ""} onClick={() => setShowSavedOnly(false)}>All results <span>{prediction.results.length}</span></button><button type="button" className={showSavedOnly ? "active" : ""} onClick={() => setShowSavedOnly(true)}>♡ My shortlist <span>{saved.length}</span></button></div>
              <div className="table-toolbar"><div className="search-wrap"><span>⌕</span><input aria-label="Search results" value={search} onChange={e=>setSearch(e.target.value)} placeholder="Search college, branch, code…"/></div><button className="export-button" type="button" onClick={exportCSV} disabled={!shown.length} title="Download currently filtered results as CSV">↓ Export CSV</button><select aria-label="Filter cutoff status" value={status} onChange={e=>setStatus(e.target.value)}><option value="all">All statuses</option><option value="within">Within historical cutoff</option><option value="borderline">Borderline comparisons</option><option value="outside">Beyond historical cutoff</option></select><select aria-label="Sort results" value={sortBy} onChange={e=>setSortBy(e.target.value)}><option value="recommended">Recommended order</option><option value="cutoff-asc">Closing rank: low to high</option><option value="cutoff-desc">Closing rank: high to low</option><option value="college">College name A–Z</option></select></div>
              <div className="table-wrap">
                <table><thead><tr><th>COLLEGE / CODE</th><th>BRANCH</th><th>LOCATION / SEAT TYPE</th><th>CATEGORY</th><th>CLOSING RANK</th><th>HISTORICAL STATUS</th><th>SHORTLIST</th></tr></thead>
                <tbody>{shown.map((x,i)=><tr key={`${x.college_code}-${x.branch}-${x.category}-${x.cutoff_rank}-${i}`}>
                  <td><div className="college-name">{x.college}</div><div className="college-code">{x.college_code ? `Code ${x.college_code}` : "Code unavailable"}{x.year ? ` · ${x.year}` : ""}</div></td>
                  <td><span className="branch-name">{x.branch}</span>{x.round && <div className="sub-meta">{x.round}</div>}</td>
                  <td><div className="location-name">{x.location || "Not specified"}</div><div className="sub-meta">{x.quota || "Seat type not specified"}</div></td>
                  <td><span className="category-chip">{x.category}</span></td>
                  <td><strong className="rank-number">{x.cutoff_rank.toLocaleString("en-IN")}</strong><div className="sub-meta">{x.rank_difference>=0 ? `${x.rank_difference.toLocaleString("en-IN")} ranks of margin` : `${Math.abs(x.rank_difference).toLocaleString("en-IN")} ranks beyond`}</div></td>
                  <td><span className={`status-chip ${x.status==="Historically within cutoff" ? "status-good" : x.status==="Borderline to historical cutoff" ? "status-borderline" : "status-warn"}`}><i/>{x.status==="Historically within cutoff" ? "Within cutoff" : x.status==="Borderline to historical cutoff" ? "Borderline" : "Beyond cutoff"}</span></td>
                  <td><button type="button" className={`save-college ${isSaved(x) ? "saved" : ""}`} onClick={() => toggleSaved(x)} aria-label={isSaved(x) ? `Remove ${x.college} from shortlist` : `Save ${x.college} to shortlist`}>{isSaved(x) ? "♥ Saved" : "♡ Save"}</button></td>
                </tr>)}</tbody></table>
                {!shown.length && <div className="table-empty">{showSavedOnly && !saved.length ? "Your shortlist is empty. Use the Save button on any college to keep it here." : "No records match the current search and filters."}</div>}
              </div>
              <div className="table-footer"><span>Showing {shown.length.toLocaleString("en-IN")} {showSavedOnly ? "saved colleges" : `of ${prediction.matched_rows.toLocaleString("en-IN")} matching records returned by the API`}.</span><span>Historical data · Not an admission guarantee</span></div>
            </>
          )}
        </section>
      </div>
      <footer className="app-footer"><span>KCET Predictor <b>·</b> College discovery workspace</span><span>Verify seat type, category, round and official KEA cutoffs before making decisions.</span></footer>
    </main>
  );
}
