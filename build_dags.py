"""Draw two alternative causal hypotheses; neither is identified by the survey."""

from pathlib import Path
from PIL import Image, ImageDraw, ImageFont
import math
import sys
import PIL

ROOT = Path(sys.argv[1] if len(sys.argv) > 1 else Path(__file__).resolve().parent / "results")
ROOT.mkdir(parents=True, exist_ok=True)
def font_path(bold=False):
    pairs = [("C:/Windows/Fonts/arial.ttf", "C:/Windows/Fonts/arialbd.ttf"),
             ("/usr/share/fonts/truetype/liberation2/LiberationSans-Regular.ttf", "/usr/share/fonts/truetype/liberation2/LiberationSans-Bold.ttf"),
             ("/usr/share/fonts/truetype/dejavu/DejaVuSans.ttf", "/usr/share/fonts/truetype/dejavu/DejaVuSans-Bold.ttf"),
             ("/System/Library/Fonts/Supplemental/Arial.ttf", "/System/Library/Fonts/Supplemental/Arial Bold.ttf")]
    for pair in pairs:
        if Path(pair[int(bold)]).exists():
            return pair[int(bold)]
    raise RuntimeError("Install Arial, Liberation Sans or DejaVu Sans to render the DAG labels")
FONT = ImageFont.truetype(font_path(), 29)
FONT_BOLD = ImageFont.truetype(font_path(True), 31)
SMALL = ImageFont.truetype(font_path(), 25)

NODES = {
    "C": (80, 80, 470, 200, "Recorded attributes\nage, gender, setting,\nspecialty", "#E9EFF6"),
    "E": (80, 360, 470, 480, "Unmeasured prior AI\ninterest and trust", "#FCECEC"),
    "A": (590, 80, 1000, 200, "Pre-use tool access\n(not directly measured)", "#FCECEC"),
    "U": (590, 360, 1000, 480, "Clinical tool use\n(underlying behavior)", "#FCECEC"),
    "Y": (1110, 360, 1520, 480, "Willingness to base\ndiagnosis on AI", "#DBEBF9"),
    "M": (590, 670, 1000, 790, "Self-reported tool use\n(digital tools and AI)", "#DBEBF9"),
    "S": (1110, 670, 1520, 790, "Survey inclusion\n(sample conditioned)", "#F1F3F5"),
}


def arrow(draw, pts, color="#31648B", width=5):
    draw.line(pts, fill=color, width=width, joint="curve")
    x0, y0 = pts[-2]
    x1, y1 = pts[-1]
    a = math.atan2(y1 - y0, x1 - x0)
    size = 18
    wing = 0.55
    p1 = (x1 - size * math.cos(a - wing), y1 - size * math.sin(a - wing))
    p2 = (x1 - size * math.cos(a + wing), y1 - size * math.sin(a + wing))
    draw.polygon([(x1, y1), p1, p2], fill=color)


def make(reverse=False):
    img = Image.new("RGB", (1600, 900), "#FFFFFF")
    d = ImageDraw.Draw(img)
    title = "DAG B   willingness may precede tool use" if reverse else "DAG A   tool use may precede willingness"
    d.text((80, 12), title, font=FONT_BOLD, fill="#152737")
    # Shared pathways, drawn before nodes so arrow shafts never obscure labels.
    arrow(d, [(470, 140), (590, 140)])  # measured context -> access
    arrow(d, [(440, 200), (590, 390)])  # measured context -> use
    arrow(d, [(270, 200), (270, 270), (1315, 270), (1315, 360)])  # context -> willingness
    arrow(d, [(795, 200), (795, 360)])  # access -> use
    arrow(d, [(470, 420), (590, 420)], color="#B34E4E")  # interest -> use
    arrow(d, [(470, 380), (520, 315), (1315, 315), (1315, 360)], color="#B34E4E")
    arrow(d, [(270, 480), (270, 835), (1315, 835), (1315, 790)], color="#B34E4E")
    if reverse:
        arrow(d, [(1110, 420), (1000, 420)], color="#0A7894", width=7)
    else:
        arrow(d, [(1000, 420), (1110, 420)], color="#0A7894", width=7)
    arrow(d, [(795, 480), (795, 670)])  # true use -> recorded use
    arrow(d, [(980, 480), (1070, 610), (1110, 700)])  # use -> selection
    arrow(d, [(1315, 480), (1315, 670)])  # willingness -> selection
    for key, (x0, y0, x1, y1, label, fill) in NODES.items():
        border = "#B34E4E" if key in {"E", "A", "U"} else "#678198"
        d.rounded_rectangle((x0, y0, x1, y1), radius=18, fill=fill, outline=border, width=3)
        bbox = d.multiline_textbbox((0, 0), label, font=FONT, spacing=4, align="center")
        tw, th = bbox[2] - bbox[0], bbox[3] - bbox[1]
        d.multiline_text((x0 + (x1-x0-tw)/2, y0 + (y1-y0-th)/2 - 3), label,
                         font=FONT, fill="#172B3B", spacing=4, align="center")
    d.text((80, 850), "Red: unmeasured constructs. Teal: alternative temporal ordering. See Tables 4 and 5.",
           font=SMALL, fill="#425466")
    path = ROOT / ("DAG_B.png" if reverse else "DAG_A.png")
    img.save(path, optimize=True)
    print(path)


make(False)
make(True)
top = Image.open(ROOT / "DAG_A.png")
bottom = Image.open(ROOT / "DAG_B.png")
combined = Image.new("RGB", (1600, 1800), "white")
combined.paste(top, (0, 0))
combined.paste(bottom, (0, 900))
supplement = ROOT / "S2_fig.png"
combined.save(supplement, dpi=(300, 300), optimize=True)
print(supplement)

(ROOT / "python_environment.txt").write_text("Python " + sys.version + "\nPillow " + PIL.__version__ + "\nFont " + font_path() + "\n", encoding="utf-8")

# Browser-friendly copy of the TIFF; pixels and labels are unchanged.
if (ROOT / "Fig1.tif").exists():
    with Image.open(ROOT / "Fig1.tif") as figure:
        figure.save(ROOT / "Fig1.png", dpi=(300, 300), optimize=True)
