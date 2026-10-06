"""Lossless export of the supplied coded jamovi master; Python standard library only.

This is not a reconstruction of the untouched survey export. No response value,
record, or source column is changed. Local handoff does not authorize publication.
Run: python prepare_dataset.py
"""
from collections import Counter
import csv
import hashlib
import json
from pathlib import Path
import struct
from zipfile import ZipFile

ROOT = Path(__file__).resolve().parent
DATA = ROOT / "data"
SOURCE = DATA / "source_coded_master.omv"


def dump_csv(path, rows, fields):
    with path.open("w", encoding="utf-8", newline="") as stream:
        w = csv.DictWriter(stream, fieldnames=fields, lineterminator="\n")
        w.writeheader()
        w.writerows(rows)


def sha256(path):
    return hashlib.sha256(path.read_bytes()).hexdigest()


def main():
    with ZipFile(SOURCE) as z:
        if z.testzip() is not None:
            raise ValueError("Damaged source archive")
        metadata = json.loads(z.read("metadata.json"))["dataSet"]
        labels = json.loads(z.read("xdata.json"))
        n, p = metadata["rowCount"], metadata["columnCount"]
        fields = metadata["fields"]
        raw = z.read("data.bin")
    assert (n, p) == (301, 42)
    assert all(f["dataType"] == "Integer" for f in fields)
    assert len(raw) == n * p * 4
    assert not any(f.get("missingValues") for f in fields)
    names = [f["name"] for f in fields]
    assert len(set(names)) == p
    values = struct.unpack(f"<{n*p}i", raw)
    cols = [values[j*n:(j+1)*n] for j in range(p)]
    assert -(2**31) not in values, "Missing integer encountered"
    rows = [dict(zip(names, (col[i] for col in cols))) for i in range(n)]
    output = DATA / "dental_ai_complete_clean.csv"
    dump_csv(output, rows, names)

    barriers = names[14:21]
    preferences = names[28:34]
    assert barriers[0] == "High cost of AI technologies"
    assert preferences[0] == "Online workshops"
    quality = []
    seen = {}
    for index, row in enumerate(rows, start=1):
        key = tuple(row[name] for name in names)
        if key in seen:
            quality.append(dict(data_row=index, variable="All 42 source fields",
                issue="Repeated response pattern", recorded_value=f"Same as data row {seen[key]}",
                derived_value="", action="Retained; identical answers do not prove duplicate identity"))
        else:
            seen[key] = index
        for aggregate, components in [("Perceived Barriers to AI adoption", barriers),
                                      ("Preferred methods", preferences)]:
            total = sum(row[name] == 1 for name in components)
            if total != row[aggregate]:
                quality.append(dict(data_row=index, variable=aggregate,
                    issue="Recorded aggregate differs from count of selected component items",
                    recorded_value=row[aggregate], derived_value=total,
                    action="Source value retained; excluded from manuscript analyses; aggregate definition unavailable"))
    dump_csv(DATA / "data_quality_flags.csv", quality,
        ["data_row", "variable", "issue", "recorded_value", "derived_value", "action"])

    notes = {
        "Age": "Age bands, not exact age. Labels preserved from coded master. Administered questionnaire has overlapping boundaries at 30, 40, 50; allocation history is unavailable.",
        "Type of dental practice": "Work setting, not recruitment site. Codes 4 and 5 combine as Mixed only in analytical derivations.",
        "Primary Dental Specialisation": "Includes Clinical Academics, which is a role rather than a specialty. General dentist = code 2; other codes form a heterogeneous comparison group.",
        "Are you familiar with AI and its' concepts?": "Code 2 label misspelling preserved verbatim from source; means Disagree. Positive = codes 3/4.",
        "Have you used AI tools in dental academics": "Administered wording combines digital tools AND AI technologies. Code 1=No, 3=Yes. Source heading is abbreviated and must not be interpreted as AI-only use.",
        "Have you used AI tools in clinical practice": "Administered wording combines digital tools AND AI technologies. Code 1=No, 3=Yes. Source heading is abbreviated and must not be interpreted as AI-only use.",
        "Availability of AI tools in clinical practice": "Options mix access, cost and behavior. Do not treat as a monotonic access score or pre-use exposure.",
        "Perceived Barriers to AI adoption": "Undocumented aggregate retained unchanged; differs from count of seven selected indicators in 5 rows. Excluded from manuscript. Derived item count is separate and is not a validated scale.",
        "Preferred methods": "Undocumented aggregate retained unchanged; differs from count of six selected indicators in 4 rows. Excluded from manuscript. Derived item count is separate and is not a validated scale.",
        "Online workshops": "Source heading says Online workshops; source value label says Online courses. Preserve discrepancy; no assumption about an unobserved response.",
        "Experience with AI": "52 entries differ from the later coded CSV; source-master values retained. This variable is not used in manuscript models.",
        "Years of Dental Clinical practice": "Recorded integer years of clinical practice; does not reconstruct exact age or academic experience.",
        "Anticipate AI becoming part of dental education": "Source labels use 6-10 and 11-15 years; questionnaire prints 5-10 and 10-15. Source categories retained; exact boundary allocation history unavailable.",
        "Anticipate AI becoming part of dental clinical practice": "Source labels use 6-10 and 11-15 years; questionnaire prints 5-10 and 10-15. Source categories retained; exact boundary allocation history unavailable.",
    }
    manuscript = set(names[:8] + barriers + [names[35], names[40], names[41], names[9]])
    codebook = []
    label_rows = []
    for j, f in enumerate(fields):
        name = f["name"]
        levels = labels.get(name, {}).get("labels", [])
        allowed = [int(x[0]) for x in levels]
        counts = Counter(cols[j])
        if levels:
            assert set(counts).issubset(allowed), (name, counts, allowed)
        for level in levels:
            label_rows.append(dict(variable=name, code=level[0],
                display_label="Disagree" if level[1] == "Disgaree" else level[1],
                source_label=level[1]))
        codebook.append(dict(column_index=j+1, variable=name,
            source_measure_type=f["measureType"], storage_type="integer",
            source_description=f.get("description", ""),
            valid_codes="|".join(map(str, allowed)),
            value_labels=json.dumps({str(x[0]): x[1] for x in levels}, ensure_ascii=False),
            observed_min=min(counts), observed_max=max(counts), missing_n=0,
            observed_counts=json.dumps(dict(sorted(counts.items()))),
            manuscript_role="Used in manuscript summaries/models/sensitivities" if name in manuscript else "Retained complete source field; not a manuscript analysis outcome",
            interpretation_note=notes.get(name, "Labels are the coded-master labels; agreement with untouched responses awaits the response-to-analysis map.")))
    dump_csv(DATA / "codebook.csv", codebook, list(codebook[0]))
    dump_csv(DATA / "value_labels.csv", label_rows, list(label_rows[0]))
    # A separate derived table exposes the recodes without altering the complete export.
    derived = []
    setting = {1: "Public", 2: "Private", 3: "Academic", 4: "Mixed", 5: "Mixed"}
    for i, r in enumerate(rows, 1):
        derived.append(dict(data_row=i,
            age_31_60=int(r["Age"] >= 2), female=int(r["Gender"] == 2),
            practice_years=r["Years of Dental Clinical practice"],
            practice_group=setting[r["Type of dental practice"]],
            general_dentist=int(r["Primary Dental Specialisation"] == 2),
            familiarity_positive=int(r[names[5]] in (3, 4)),
            academic_tool_use=int(r[names[6]] == 3),
            clinical_tool_use=int(r[names[7]] == 3),
            diagnostic_confidence=int(r[names[35]] in (3, 4)),
            diagnostic_willingness=int(r[names[41]] == 1),
            education_willingness=int(r[names[40]] == 1),
            selected_barrier_item_count=sum(r[v] == 1 for v in barriers),
            selected_training_method_count=sum(r[v] == 1 for v in preferences)))
    dump_csv(DATA / "derived_analysis_variables.csv", derived, list(derived[0]))
    # Read-back verifies export and typing, not merely successful file creation.
    with output.open(encoding="utf-8", newline="") as stream:
        reader = csv.DictReader(stream)
        assert reader.fieldnames == names
        back = [{k: int(v) for k, v in r.items()} for r in reader]
    assert rows == back
    audit = dict(status="Lossless, structurally clean coded analysis export; original-response reconciliation outstanding",
        source_original_filename="02. Research Data (TOTAL).omv",
        source_sha256=sha256(SOURCE), csv_sha256=sha256(output),
        csv_md5=hashlib.md5(output.read_bytes()).hexdigest(),
        rows=n, columns=p, cells_checked=n*p, missing_cells=0,
        invalid_labelled_codes=0, changed_response_values=0, excluded_rows=0,
        repeated_pattern_rows=[66, 67], quality_flag_rows=len(quality),
        row_identifier="data_row is a 1-based archive position, not an original survey identifier",
        source_limitations=["Untouched response export and respondent-level coding history unavailable",
            "Recruitment sites, response timestamps, exclusions and consent records absent from coded data",
            "No source identity fields; rare attribute combinations can still pose disclosure risk",
            "Institutional approval for public release remains outstanding"],
        file_sha256={f.name: sha256(f) for f in sorted(DATA.iterdir()) if f.is_file() and f.suffix in (".csv", ".omv") and f.name != "checksums.csv"})
    (DATA / "data_validation.json").write_text(json.dumps(audit, indent=2)+"\n", encoding="utf-8")
    checksums = [dict(file=f.name, md5=hashlib.md5(f.read_bytes()).hexdigest(), sha256=sha256(f))
        for f in sorted(DATA.iterdir()) if f.is_file() and f.name != "checksums.csv"]
    dump_csv(DATA / "checksums.csv", checksums, ["file", "md5", "sha256"])
    print(json.dumps({k: audit[k] for k in ["rows", "columns", "cells_checked", "missing_cells", "changed_response_values", "quality_flag_rows", "csv_sha256"]}, indent=2))


if __name__ == "__main__":
    main()
