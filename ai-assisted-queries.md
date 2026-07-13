# AI-Assisted Querying: Plain-English Questions Against the Pharmacy Database

This project was developed with LLM-assisted coding as a standard part of the workflow —
drafting and debugging SQL and R, and documenting the pipeline. This file shows what that
looks like in practice: real questions asked in plain English, the SQL an LLM drafted from
the schema, and the review step applied before trusting the output.

**Workflow for every query below:**
1. Describe the question in plain English, along with the table schema
2. Review the generated SQL line-by-line (joins, filters, NULL handling)
3. Validate the result against a known figure or a manual spot-check
4. Commit only queries that pass review

The review step is not optional. LLM-drafted SQL is a fast first draft, not an answer —
the epidemiological judgment (what counts as a pharmacy, how to classify chains, how to
handle unknowns) stays with the analyst.

**Schema notes (analysis table `pharmacy_analysis`, one row per licensed facility):**
`REGNO` = NYS registration number; `PH_TYPE_DESC` = license type (the raw permit file
includes wholesalers and manufacturers, not only pharmacies); `pharmacy_regroup` =
project classification (Independent, Large Chain, Small Chain, Hospital affiliate, ...);
`NYC_borough` = borough; `BoroCT2020` = 2020 census tract; `PPovPop` = tract poverty %
(ACS); `PHSP` = tract % Hispanic (Census); `MuaSCORE` = HRSA Medically Underserved Area
score.

---

## Question 1 — Which census tracts depend on a single independent pharmacy?

**Plain-English prompt:** "Find census tracts where exactly one retail pharmacy exists
and it is classified as Independent — the tracts most exposed if that one pharmacy
closes."

```sql
WITH retail AS (
    SELECT BoroCT2020, NYC_borough, pharmacy_regroup, LEG_NAME
    FROM pharmacy_analysis
    WHERE PH_TYPE_DESC = 'PHARMACY - NYS'          -- exclude wholesalers/manufacturers
      AND pharmacy_regroup NOT IN ('Unknown')
),
tract_counts AS (
    SELECT BoroCT2020, COUNT(*) AS n_pharmacies
    FROM retail
    GROUP BY BoroCT2020
    HAVING COUNT(*) = 1
)
SELECT r.BoroCT2020, r.NYC_borough, r.LEG_NAME
FROM retail r
JOIN tract_counts t ON r.BoroCT2020 = t.BoroCT2020
WHERE r.pharmacy_regroup = 'Independent'
ORDER BY r.NYC_borough, r.BoroCT2020;
```

**Review notes:** The first draft queried the raw table without the `PH_TYPE_DESC`
filter, silently counting 131 wholesalers and manufacturers as pharmacies. Caught in
line-by-line review — the licensed-facility file is not a pharmacy file until you make
it one. This is the single most common error an unreviewed text-to-SQL workflow would
ship.

**Validated result:** 451 census tracts have exactly one retail pharmacy, and it is an
independent — 451 single points of failure for neighborhood pharmaceutical access.

---

## Question 2 — How does chain share differ between high-poverty and lower-poverty tracts?

**Plain-English prompt:** "Compare the percentage of retail pharmacies that are chains
(Large or Small Chain) in tracts at or above 20% poverty versus below, using the
tract-level ACS poverty already joined to each pharmacy."

```sql
SELECT
    CASE WHEN PPovPop >= 20 THEN 'High poverty (>=20%)'
         ELSE 'Lower poverty (<20%)' END          AS tract_group,
    COUNT(*)                                       AS total_pharmacies,
    SUM(CASE WHEN pharmacy_regroup IN ('Large Chain','Small Chain')
             THEN 1 ELSE 0 END)                    AS chain_count,
    ROUND(100.0 * SUM(CASE WHEN pharmacy_regroup IN ('Large Chain','Small Chain')
                           THEN 1 ELSE 0 END) / COUNT(*), 1) AS pct_chain,
    SUM(CASE WHEN pharmacy_regroup = 'Independent'
             THEN 1 ELSE 0 END)                    AS independent_count
FROM pharmacy_analysis
WHERE PH_TYPE_DESC = 'PHARMACY - NYS'
  AND PPovPop IS NOT NULL
GROUP BY 1
ORDER BY 1;
```

**Review notes:** Validated the direction of the result against the project's spatial
lag regression (chain presence negatively associated with tract poverty, p < 0.001,
and with % Hispanic, p = 0.002). The SQL gives the descriptive version of the
inferential finding; the two methods agree.

**Validated result:** In tracts at or above 20% poverty, 7.1% of retail pharmacies are
chains and 87.6% are independents; in lower-poverty tracts, chain share is 16.7% —
chains are 2.4× more present where poverty is lower.

---

## Question 3 — Independent-pharmacy reliance by borough, ordered by poverty

**Plain-English prompt:** "By borough, show the share of retail pharmacies that are
independent alongside average tract poverty and average MUA score — a borough-level
view of where access depends on independents."

```sql
SELECT
    NYC_borough,
    COUNT(*)                                        AS total_pharmacies,
    ROUND(100.0 * SUM(CASE WHEN pharmacy_regroup = 'Independent'
                           THEN 1 ELSE 0 END) / COUNT(*), 1) AS pct_independent,
    ROUND(AVG(PPovPop), 1)                          AS avg_tract_poverty_pct,
    ROUND(AVG(MuaSCORE), 1)                         AS avg_mua_score
FROM pharmacy_analysis
WHERE PH_TYPE_DESC = 'PHARMACY - NYS'
  AND NYC_borough <> 'Unknown'
GROUP BY NYC_borough
ORDER BY avg_tract_poverty_pct DESC;
```

**Review notes:** Two data-quality findings from review rather than from the LLM:
(1) the source data spells the borough 'Manhatten' — filters and labels must match the
data as it exists, not as it should be spelled; (2) 8 facilities carry borough
'Unknown' and are excluded here but retained in the spatial analysis, where coordinates
rather than borough labels drive the methods.

**Validated result:** The Bronx — the highest-poverty borough (31.2% average tract
poverty) — depends on independents for 86.0% of its retail pharmacies; Manhattan, at
17.2% poverty, for 67.9%. Reliance on independent pharmacies rises with poverty.

---

## Related: the closure analysis

The five-year closure identification (2019 vs. 2024 permit files, dual-key join on
registration number and geocoded coordinates) lives in the production pipeline —
see [`pharmacy_closures_2019_2024.sql`](pharmacy_closures_2019_2024.sql). The same
LLM-assisted draft → line-by-line review → validate-against-known-totals workflow
was used to build it.
