"""Validate committed aggregate results and protect the code-only upload boundary.

This does not rerun participant-level analyses; an approved local data package
is needed for those. Standard library only: python tests/check_public_release.py
"""
import csv
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]


def rows(path):
    with (ROOT / path).open(encoding="utf-8-sig", newline="") as stream:
        return list(csv.DictReader(stream))


def main():
    forbidden = {"dental_ai_complete_clean.csv", "derived_analysis_variables.csv",
                 "data_quality_flags.csv", "source_coded_master.omv"}
    for path in ROOT.rglob("*"):
        if not path.is_file() or ".git" in path.parts:
            continue
        assert path.name not in forbidden, f"Participant-level file in public tree: {path}"
        assert path.suffix.lower() not in {".omv", ".rds", ".rdata", ".zip"}, path
        assert path.name not in {".env", ".Renviron", ".Rhistory"}, path
    reference = rows("reference_table5.csv")
    result = rows("aggregate_results/table5_all_descriptive_pathways.csv")
    assert len(reference) == len(result) == 12
    count = 0
    for expected, actual in zip(reference, result):
        assert (expected["panel"], expected["contrast"]) == (actual["panel"], actual["contrast"])
        for name in expected:
            if name.endswith("_pp"):
                assert abs(float(expected[name])-float(actual[name])) <= 0.05000001, (name, expected, actual)
                count += 1
        assert abs(float(actual["total_pp"])-float(actual["direct_pp"])-float(actual["indirect_pp"])) < 1e-9
        assert int(actual["bootstrap_valid"]) == 1000
    assert count == 108
    diag = rows("aggregate_results/bootstrap_numerical_diagnostics.csv")
    assert sum(int(x["flagged_bootstrap"]) for x in diag) == 45
    table2 = rows("aggregate_results/table2_responses_and_barriers.csv")
    assert len(table2) == 13
    assert [int(x["count"]) for x in table2] == [268,216,174,110,262,155,196,177,141,125,83,81,54]
    paired = rows("aggregate_results/figure1_paired_cells.csv")
    assert [int(x["Freq"]) for x in paired] == [59,87,26,129]
    print("PASS: public file boundary, 108 pathway values, identities, bootstrap diagnostics, 13 item totals and four paired cells")
    print("Scope: aggregate release checks; participant-level analyses were reproduced locally.")


if __name__ == "__main__":
    main()
